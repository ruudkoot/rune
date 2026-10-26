(* The soundness of fingerprints (docs/plans/functors-units.md, M4): a usage
   holds where the fingerprint of what its name names is the same, so a
   new way of working fingerprints out must tell apart every two things the
   old way told apart. Over a project's edits, both compilers build each
   state into a cache of their own, and their entries' usages are compared:
   wherever a unit keeps the same usage in two states one after another and
   the old compiler's fingerprint of it changed, the new compiler's must
   have changed too. Where it did not, the new compiler would take an entry
   that the old one missed: a violation, unless it is one of the
   refinements intended (*Refinements*). A change of the new fingerprint
   that the old did not see is counted too: it is a miss the new compiler
   makes and the old did not.

   The entries are read here, apart from UnitCache: a usage list is the
   first thing in an entry's body in every version of its format, so any
   compiler can be either side. --weaken N cuts the new fingerprints to N
   digits, a weak hash, which the check must catch. *)
structure Soundness =
struct
  open Incremental

  (* The units of a cache: each entry's source name and usages, a usage as
     its key and the fingerprint of its value ("IDENTITY FINGERPRINT") *)
  fun entry file : (string * (string * string) list) option =
    (let
       val text = CachePlant.binary file
       val () = CachePlant.need (String.isPrefix "RCE" text, "not a cache entry: " ^ file)
       val (_, at) = CachePlant.natural text 3
       val (_, at) = CachePlant.stringAt text at
       val (count, at) = CachePlant.natural text at
       fun pairs (0, at, acc) = (List.rev acc, at)
         | pairs (n, at, acc) =
             let val (k, at) = CachePlant.stringAt text at
                 val (v, at) = CachePlant.stringAt text at
                 val fp = case List.rev (String.fields (fn c => c = #" ") v) of fp :: _ => fp | [] => v
             in pairs (n - 1, at, (k, fp) :: acc) end
       val (usages, at) = pairs (IntInf.toInt count, at, [])
       val (warnings, at) = CachePlant.natural text at
       fun skip (0, at) = at | skip (n, at) = skip (n - 1, #2 (CachePlant.stringAt text at))
       val at = skip (IntInf.toInt warnings, at)
       val (source, _) = CachePlant.stringAt text at
     in SOME (source, usages) end)
    handle CachePlant.Invalid _ => NONE

  fun units dir : (string * (string * string) list) list =
    let fun walk path = if isDir path then List.concat (List.map (fn name => if name = "units" then [] else walk (path ^ "/" ^ name))
                                                                  (entries path))
                        else if String.isSubstring ".tmp-" path then [] else [path]
    in List.mapPartial entry (if exists dir then walk dir else []) end

  type side = {compiler : string, weaken : int option}
  type tally = {pairs : int ref, violations : int ref, finer : int ref, compared : int ref, shown : int ref}

  (* the units of the project as it is, built by side's compiler into a
     cache of its own *)
  fun snapshot (s : state) (side : side) tag =
    let
      val cache = path s ("cache-" ^ tag)
      val () = rmTree cache
      val _ = command s "" (fromRoot (#compiler side) :: ["--units", "--cache-dir", cache] @ words (path s "files")
                            @ ["-o", path s ("p-" ^ tag ^ ".rbc")])
      fun weak fp = case #weaken side of SOME n => if size fp > n then String.substring (fp, 0, n) else fp | NONE => fp
    in List.map (fn (u, us) => (u, List.map (fn (k, fp) => (k, weak fp)) us)) (units cache) end

  fun find (u, k) (snap : (string * (string * string) list) list) =
    case List.find (fn (name, _) => name = u) snap of
      SOME (_, us) => Option.map #2 (List.find (fn (key, _) => key = k) us)
    | NONE => NONE

  (* two states one after another, each by both sides *)
  fun compare (t : tally) what ((old0, new0), (old1, new1)) =
    let
      val () = #pairs t := !(#pairs t) + 1
      fun one (u, us) =
        List.app (fn (k, o0) =>
                    case (find (u, k) old1, find (u, k) new0, find (u, k) new1) of
                      (SOME o1, SOME n0, SOME n1) =>
                        (#compared t := !(#compared t) + 1;
                         if o0 <> o1 andalso n0 = n1 then
                           (#violations t := !(#violations t) + 1;
                            if !(#shown t) < 20
                            then (#shown t := !(#shown t) + 1;
                                  say ("VIOLATION " ^ what ^ ": " ^ u ^ " " ^ k ^ ": old " ^ o0 ^ " -> " ^ o1 ^ ", new " ^ n0 ^ " both\n"))
                            else ())
                         else if o0 = o1 andalso n0 <> n1 then #finer t := !(#finer t) + 1
                         else ())
                    | _ => ()) us
    in List.app one old0 end

  fun tally () : tally = {pairs = ref 0, violations = ref 0, finer = ref 0, compared = ref 0, shown = ref 0}

  (* the edits of a project, as the cache's mutations make them, with one
     more kind: a type variable or a type made to admit equality, or no
     longer (build-cache issue 16) *)
  fun equality generator (p : MutationProject.project) =
    let
      val tyvars = MutationProject.candidates p (List.filter (fn t : SmlScan.token => String.isPrefix "'" (#text t)))
      val eqtypes = MutationProject.candidates p (List.filter (fn t : SmlScan.token => #text t = "type" orelse #text t = "eqtype"))
    in
      case MutationProject.choose generator (tyvars @ eqtypes) of
        NONE => NONE
      | SOME (file, t) =>
          let val replacement = if #text t = "type" then "eqtype" else if #text t = "eqtype" then "type"
                                else if String.isPrefix "''" (#text t) then String.extract (#text t, 1, NONE) else "'" ^ #text t
          in MutationProject.splice p file (#start t) (#finish t) replacement; SOME ("equality in " ^ file) end
    end

  fun next generator p =
    if MutationProject.number generator 5 = 0 then
      (case equality generator p of SOME d => d | NONE => #2 (MutationProject.next generator p))
    else #2 (MutationProject.next generator p)

  fun project (t : tally) (old : side) (new : side) directory generator steps (spec, sources) =
    let
      val p = MutationProject.create (#compiler new) directory sources []
      val s = #state p
      fun state () = (put s "files" (String.concatWith "\n" (!(#files p))); (snapshot s old "old", snapshot s new "new"))
      fun go (0, _) = ()
        | go (n, before') =
            let val what = next generator p
                val now = state ()
            in compare t (spec ^ ", " ^ what) (before', now); go (n - 1, now) end
    in go (steps, state ()) end

  (* Each a project in two states, the second with one name made to admit
     equality or no longer: build-cache issue 16's probes (E9) *)
  val probes : (string * (string * string) list * (string * string) list) list = [
    ("val", [("a.sml", "fun f (x : 'a) = 0"), ("b.sml", "val y = f 1")],
            [("a.sml", "fun f x = if x = x then 0 else 1"), ("b.sml", "val y = f 1")]),
    ("str", [("a.sml", "structure A = struct fun f (x : 'a) = 0 end"), ("b.sml", "val y = A.f 1")],
            [("a.sml", "structure A = struct fun f x = if x = x then 0 else 1 end"), ("b.sml", "val y = A.f 1")]),
    ("sigeq", [("a.sml", "signature S = sig type t end"), ("b.sml", "structure X : S = struct type t = int end")],
              [("a.sml", "signature S = sig eqtype t end"), ("b.sml", "structure X : S = struct type t = int end")]),
    ("sigar", [("a.sml", "signature S = sig type t val x : int end"), ("b.sml", "structure X : S = struct type t = int val x = 1 end")],
              [("a.sml", "signature S = sig type 'a t val x : int end"), ("b.sml", "structure X : S = struct type 'a t = int val x = 1 end")]),
    ("funpar", [("a.sml", "functor F (X : sig type t end) = struct end"), ("b.sml", "structure Y = F (struct type t = int end)")],
               [("a.sml", "functor F (X : sig eqtype t end) = struct end"), ("b.sml", "structure Y = F (struct type t = int end)")])]

  fun probe (t : tally) (old : side) (new : side) directory (name, first, second) =
    let
      val p = MutationProject.create (#compiler new) (directory ^ "/probe-" ^ name) first []
      val s = #state p
      fun state () = (put s "files" (String.concatWith "\n" (!(#files p))); (snapshot s old "old", snapshot s new "new"))
      val a = state ()
      val () = List.app (fn (file, text) => MutationProject.write p file text) second
    in compare t ("probe " ^ name) (a, state ()) end

  fun summary (t : tally) =
    say ("soundness: " ^ Int.toString (!(#pairs t)) ^ " pairs of states, " ^ Int.toString (!(#compared t)) ^ " usages compared, "
         ^ Int.toString (!(#violations t)) ^ " violations, " ^ Int.toString (!(#finer t)) ^ " changes the old fingerprint did not see\n")
end
