(* Differential cache oracle, replay receipts and failure snapshots. Neither
   side's exit status alone is an oracle for the other side's bytecode. *)
structure MutationChecks =
struct
  open Incremental
  type checker = {compiler : string, directory : string, flags : string list,
                  builds : int ref, failures : int ref, compiled : int ref, across : int ref}
  fun create compiler directory flags : checker =
    (mkdirs directory; {compiler = fromRoot compiler, directory = directory, flags = flags,
                       builds = ref 0, failures = ref 0, compiled = ref 0, across = ref 0})
  fun check (checker : checker) (project : MutationProject.project) history =
    let val s = #state project
        val () = put s "files" (String.concatWith "\n" (!(#files project)))
        val () = #builds checker := !(#builds checker) + 1
        val label = Int.toString (!(#builds checker))
        val flags = #flags checker @ (if null (#basis project) then [] else ["--lib", path s "lib"])
        val cacheFlags = ["--units"] @ flags @ ["--cache-dir", #directory checker ^ "/cache", "--explain-rebuild"]
        val freshFlags = ["--units"] @ flags @ ["--no-cache"]
        val () = (rmTree (path s "p.rbc"); rmTree (path s "nocache.rbc"))
        val cached = compile s cacheFlags "p.rbc"
        val plain = compile s freshFlags "nocache.rbc"
        val () = need (#status cached <> 124 andalso #status plain <> 124, "mutation compiler exceeded its deadline")
        val compiled = length (List.filter (fn line => String.isPrefix "rune: compiled " line andalso not (String.isSubstring "lib/basis" line)) (lines (#errors cached)))
        val across = length (List.filter (fn line => String.isPrefix "rune: from the cache " line andalso String.isSubstring ", across " line) (lines (#errors cached)))
        val built = #status plain = 0
        val agreement = (#status cached = 0) = built andalso (not built orelse same (path s "p.rbc", path s "nocache.rbc"))
        val () = #compiled checker := !(#compiled checker) + compiled
        val () = #across checker := !(#across checker) + across
        val () = if agreement then () else
          let val () = #failures checker := !(#failures checker) + 1
              val directory = #directory checker ^ "/failure-" ^ Int.toString (!(#failures checker))
              val () = copyTree (!(#directory s)) directory
              val () = write (directory ^ "/history", String.concatWith "\n" history ^ "\n")
              val () = write (directory ^ "/cached.err", #errors cached)
              val () = write (directory ^ "/nocache.err", #errors plain)
          in say ("FAIL mutate: disagreement after " ^ List.last history ^ " (" ^ directory ^ ")\n") end
        val () = append (#directory checker ^ "/steps.tsv", String.concatWith "\t"
                [label, Bool.toString built, Int.toString compiled, Int.toString across, Bool.toString agreement, List.last history] ^ "\n")
    in {agreement = agreement, built = built, compiled = compiled, across = across} end
  fun field key object = case Json.member (key,object) of SOME value => value | NONE => raise Failed ("missing mutation trace field " ^ key)
  fun string (Json.String value) = value | string _ = raise Failed "mutation trace expected string"
  fun array (Json.Array values) = values | array _ = raise Failed "mutation trace expected array"
  fun object (Json.Object fields) = fields | object _ = raise Failed "mutation trace expected object"
  fun integer value = case Json.toInt value of SOME n => n | NONE => raise Failed "mutation trace expected integer"
  fun boolean (Json.Bool value) = value | boolean _ = raise Failed "mutation trace expected bool"
  fun replay compiler directory traceFile =
    let val trace = Json.decode (read traceFile)
        val () = need (integer (field "format" trace) = 1, "unknown frozen mutation trace version")
        val checker = create compiler directory []
        fun project data =
          let val name = string (field "name" data)
              val initial = List.map (fn (name,value) => (name,string value)) (object (field "initial" data))
              val p = MutationProject.create compiler (directory ^ "/work-" ^ name) initial []
              fun step (data, history) =
                let val description = string (field "description" data)
                    val history = history @ [description]
                    val () = #files p := List.map string (array (field "files" data))
                    val () = List.app (fn (file,value) => MutationProject.write p file (string value)) (object (field "writes" data))
                    val result = check checker p history
                    val () = need (#agreement result andalso #agreement result = boolean (field "agreement" data)
                              andalso #built result = boolean (field "built" data)
                              andalso #compiled result = integer (field "compiled" data)
                              andalso #across result = integer (field "across" data), "frozen mutation receipt differs: " ^ name ^ ": " ^ description)
                in history end
              val _ = List.foldl step [] (array (field "steps" data))
          in () end
        val () = List.app project (array (field "projects" trace))
    in need (!(#failures checker) = 0, "frozen mutations disagreed");
       say ("PASS mutation replay v1: " ^ Int.toString (!(#builds checker)) ^ " identical legacy receipts\n") end
  fun summary (checker : checker) =
    (say ("mutate: " ^ Int.toString (!(#builds checker)) ^ " builds, " ^ Int.toString (!(#failures checker))
          ^ " disagreements; " ^ Int.toString (!(#across checker)) ^ " units taken from the cache across a unit that changed\n");
     need (!(#failures checker) = 0, "cache differential disagreements"))
  fun generate (checker : checker) generator steps spec sources basis =
    let val name = if spec = "compiler" then "compiler" else OS.Path.file spec
        val p = MutationProject.create (#compiler checker) (#directory checker ^ "/work-" ^ name) sources basis
        val history = ref ["the project as it is"]
        val _ = check checker p (!history)
        val counts = ref [] : (string * int) list ref
        val built = ref 0
        fun step _ =
          let val (kind,description) = MutationProject.next generator p
              val () = history := !history @ [description]
              val result = check checker p (!history)
              val () = if #built result then built := !built + 1 else ()
              val beforeCount = getOpt (Option.map #2 (List.find (fn (k,_) => k = kind) (!counts)),0)
              val () = counts := (kind,beforeCount+1) :: List.filter (fn (k,_) => k <> kind) (!counts)
          in if #built result orelse MutationProject.coin generator then () else
               let val description = getOpt (MutationProject.revert generator p, "nothing to put back")
               in history := !history @ [description]; ignore (check checker p (!history)) end end
        val () = List.app step (List.tabulate (steps, fn i => i))
    in say ("mutate v2 " ^ name ^ ": " ^ Int.toString steps ^ " steps, " ^ Int.toString (!built) ^ " of them a program; edits "
            ^ String.concatWith ", " (sort (List.map (fn (name,n) => name ^ " " ^ Int.toString n) (!counts))) ^ "\n") end
end
