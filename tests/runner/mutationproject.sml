(* Mutable project for cache differential checks. Version 2 draws SplitMix64;
   version 1 is the frozen Python sequence in incremental-edits-v1.json. *)
structure MutationProject =
struct
  open Incremental
  type project = {state : state, files : string list ref, basis : string list,
                  original : (string * string) list, texts : (string * string) list ref, counter : int ref}
  fun text (p : project) file = case List.find (fn (name, _) => name = file) (!(#texts p)) of
          SOME (_, text) => text | NONE => raise Failed ("missing mutable source " ^ file)
  fun write (p : project) file value =
    (mkdirs (OS.Path.dir (path (#state p) file)); CachePlant.writeBinary (path (#state p) file) value;
     #texts p := (file, value) :: List.filter (fn (name, _) => name <> file) (!(#texts p)))
  fun create compiler directory sources basisNames : project =
    let val state = Incremental.create (OS.Path.file directory) compiler
        val () = #directory state := directory
        val () = reset state
        val basis = List.map (fn file => "lib/basis/" ^ file) basisNames
        val () = if null basis then () else Incremental.basis state
        val original = sources @ List.map (fn file => (file, CachePlant.binary (path state file))) basis
        val p = {state = state, files = ref (List.map #1 sources), basis = basis, original = original,
                 texts = ref [], counter = ref 0} : project
        val () = List.app (fn (file, value) => write p file value) original
    in p end
  fun editable (p : project) = !(#files p) @ #basis p
  fun fresh (p : project) = (#counter p := !(#counter p) + 1; Int.toString (!(#counter p)))
  fun number generator bound = let val (n, next) = Random.int (0, bound - 1) (!generator)
                               in generator := next; n end
  fun choose generator xs = if null xs then NONE else SOME (List.nth (xs, number generator (length xs)))
  fun coin generator = number generator 2 = 0
  fun splice (p : project) file start finish replacement =
    let val old = text p file
    in write p file (String.substring (old, 0, start) ^ replacement ^ String.extract (old, finish, NONE)) end
  fun tokens p file = (SmlScan.tokens (text p file) handle SmlScan.Bad _ => [])
  fun candidates p select = List.concat (List.map (fn file => List.map (fn x => (file, x)) (select (tokens p file))) (editable p))
  fun indexed tokens = ListPair.zip (tokens, List.tabulate (length tokens, fn i => i))
  fun keyword word = List.exists (fn x => x = word)
       ["val", "fun", "type", "datatype", "exception", "structure", "end", "and", "local", "in", "open", "infix", "infixr", "nonfix",
        "signature", "functor", "withtype", "abstype", "eqtype", "include", "sharing", "let"]
  fun body tokens =
    let fun loop ([], _, result) = List.rev result
          | loop ((t : SmlScan.token) :: rest, depth, result) =
              if depth = 0 andalso (keyword (#text t) orelse #text t = ";" orelse #text t = "|") then List.rev result
              else if depth = 0 andalso List.exists (fn x => #text t = x) [")", "]", "}"] then List.rev result
              else loop (rest, depth + (if List.exists (fn x => #text t = x) ["(", "[", "{"] then 1
                                       else if List.exists (fn x => #text t = x) [")", "]", "}"] then ~1 else 0), t :: result)
    in loop (tokens, 0, []) end
  fun revert generator (p : project) =
    let val changed = List.filter (fn (file, value) => text p file <> value) (#original p)
    in if number generator 10 < 3 then
         (#files p := List.map #1 (List.filter (fn (file, _) => not (List.exists (fn b => b = file) (#basis p))) (#original p));
          List.app (fn (file, value) => write p file value) (#original p); SOME "the whole project put back")
       else case choose generator changed of NONE => NONE | SOME (file, value) => (write p file value; SOME (file ^ " put back")) end
  fun edit generator (p : project) kind =
    let fun any select action = case choose generator (candidates p select) of NONE => NONE | SOME (file, value) =>
                      (action file value; SOME (kind ^ " in " ^ file))
        fun add inside = case choose generator (editable p) of NONE => NONE | SOME file =>
             let val k = fresh p
                 val addition = if kind = "comment" then "\n(* mutant " ^ k ^ " *)\n" else "\nval runeMutant" ^ k ^ " = " ^ k ^ "\n"
             in write p file (text p file ^ addition); SOME (kind ^ " in " ^ file) end
        fun findBody tokens = List.mapPartial (fn (t : SmlScan.token, i) => if #text t <> kind then NONE else
              let val rest = List.drop (tokens, i+1)
                  fun afterEquals [] = [] | afterEquals ((t : SmlScan.token) :: rest) =
                       if #text t = "=" then body rest else if keyword (#text t) then [] else afterEquals rest
              in case afterEquals rest of [] => NONE | ts => SOME (hd ts, List.last ts) end) (indexed tokens)
    in case kind of
      "fixity" => any (fn ts => List.mapPartial (fn (t : SmlScan.token, i) => if (#text t = "infix" orelse #text t = "infixr") andalso i+1 < length ts then
                     let val n = List.nth (ts, i+1) in case Int.fromString (#text n) of SOME k => SOME (t, n, k) | NONE => NONE end else NONE) (indexed ts))
                  (fn file => fn (t, n, k) => if coin generator then splice p file (#start t) (#finish n) (#text t ^ " " ^ Int.toString ((k + 1 + number generator 9) mod 10))
                       else splice p file (#start t) (#finish t) (if #text t = "infix" then "infixr" else "infix"))
    | "numeral" => any (List.filter (fn t : SmlScan.token => #kind t = SmlScan.Identifier andalso CharVector.all Char.isDigit (#text t)))
                  (fn file => fn t => let val old = valOf (IntInf.fromString (#text t))
                                     in splice p file (#start t) (#finish t) (IntInf.toString (old + IntInf.fromInt (List.nth ([1,2,7], number generator 3)))) end)
    | "top_value" => add false
    | "comment" => add false
    | "struct_value" => any (List.filter (fn t : SmlScan.token => #text t = "struct"))
                  (fn file => fn t => let val k = fresh p in splice p file (#finish t) (#finish t) (" val runeMutant" ^ k ^ " = " ^ k ^ " ") end)
    | "type" => any findBody (fn file => fn (a,b) =>
                 let val value = String.substring (text p file, #start a, #finish b - #start a)
                     val replacement = if value = "int" andalso coin generator then "IntInf.int"
                                       else if coin generator then "(" ^ value ^ ")" else value ^ " * unit"
                 in splice p file (#start a) (#finish b) replacement end)
    | "exception" => any (fn ts => List.mapPartial (fn (t : SmlScan.token,i) => if #text t = "exception" andalso i+1 < length ts then
                 let val name = List.nth (ts,i+1)
                     val tail = List.filter (fn t : SmlScan.token => #line t = #line name) (body (List.drop (ts,i+2)))
                 in if List.exists (fn t : SmlScan.token => #text t = "=") tail then NONE else SOME (name, tail) end else NONE) (indexed ts))
                 (fn file => fn (name, tail) => case tail of [] => splice p file (#finish name) (#finish name) " of int"
                    | _ => let val last = List.last tail in splice p file (#finish last) (#finish last) " * unit" end)
    | "constructors" => any (fn ts => List.mapPartial (fn (t : SmlScan.token, i) => if #text t <> "datatype" then NONE else
                 let fun begin [] = [] | begin ((t : SmlScan.token) :: rest) = if #text t = "=" then rest else if keyword (#text t) then [] else begin rest
                     fun segments [] = [] | segments xs = case body xs of [] => [] | part =>
                         let val next = List.drop (xs, length part)
                         in part :: (case next of t :: rest => if #text t = "|" then segments rest else [] | [] => []) end
                     val parts = segments (begin (List.drop (ts,i+1)))
                 in if length parts > 1 then SOME parts else NONE end) (indexed ts))
                 (fn file => fn parts =>
                   let val i = number generator (length parts)
                       val j = (i + 1 + number generator (length parts - 1)) mod length parts
                       fun span part = (#start (hd part), #finish (List.last part))
                       val (a,b) = span (List.nth (parts, Int.min (i,j)))
                       val (c,d) = span (List.nth (parts, Int.max (i,j)))
                       val source = text p file
                   in write p file (String.substring (source,0,a) ^ String.substring (source,c,d-c)
                       ^ String.substring (source,b,c-b) ^ String.substring (source,a,b-a) ^ String.extract (source,d,NONE)) end)
    | "revert" => revert generator p
    | "shadow" => if length (!(#files p)) < 2 then NONE else
         let val files = !(#files p)
             val i = number generator (length files - 1)
             val file = List.nth (files,i)
             val j = i + 1 + number generator (length files-i)
             val name = OS.Path.concat (OS.Path.dir file, "again" ^ fresh p ^ "_" ^ OS.Path.file file)
         in write p name (text p file); #files p := List.take (files,j) @ [name] @ List.drop (files,j); SOME ("shadow " ^ file ^ " as " ^ name) end
    | "swap" => if length (!(#files p)) < 2 then NONE else
         let val files = !(#files p)
             val i = number generator (length files-1)
         in #files p := List.take (files,i) @ [List.nth (files,i+1),List.nth (files,i)] @ List.drop (files,i+2); SOME "adjacent files swapped" end
    | "remove" => if length (!(#files p)) < 2 then NONE else
         let val files = !(#files p)
             val i = number generator (length files)
         in #files p := List.take (files,i) @ List.drop (files,i+1); SOME ("removed " ^ List.nth (files,i)) end
    | "rename" => (case choose generator (!(#files p)) of NONE => NONE | SOME file =>
         let val name = OS.Path.concat (OS.Path.dir file, "renamed" ^ fresh p ^ "_" ^ OS.Path.file file)
         in write p name (text p file); #files p := List.map (fn old => if old = file then name else old) (!(#files p)); SOME ("renamed " ^ file ^ " to " ^ name) end)
    | _ => raise Failed ("unknown edit kind " ^ kind)
    end
  val weighted = List.concat (List.map (fn (name,n) => List.tabulate (n, fn _ => name))
      [("fixity",3),("constructors",4),("numeral",5),("top_value",2),("struct_value",3),("comment",1),("shadow",2),("swap",1),("revert",4),("type",3),("exception",2),("remove",1),("rename",1)])
  fun next generator p =
    let fun attempt 0 = raise Failed "no applicable edit after 1000 attempts"
          | attempt n = let val kind = List.nth (weighted, number generator (length weighted))
                        in case edit generator p kind of SOME description => (kind,description) | NONE => attempt (n-1) end
    in attempt 1000 end
end
