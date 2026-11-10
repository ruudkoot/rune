(* The renamer's and the checker's part of rhc's interfaces and usages (the
   haskell98 roadmap's M21, D44, E13's H1 to H9; HsIface, B's, holds them
   with a unit's Core and codes them, and rhc's driver keeps them in the
   store).

   A module's interface is what its unit's check leaves of it
   (HsModIface: exports, definitions, fixities, its part of the checker's
   environment), and a unit can be named and checked against its imports'
   interfaces alone (RhcNames.install). What a unit's compile reads of
   them is noted as it reads (HsUsage), each read once, and what a read
   gives is `answer`'s, the same function at the compile and at a hit, so
   that a hit judges a usage against what the graph gives now (H3).

   For tests and for its use by a driver:

     rhc --typecheck-only --by-interface FILE.hs   each group of the
         program checked against the interfaces of the groups before it,
         the library's among them, which must say what a whole check says
         (the jobs hs/iface/units/...)
     rhc --dump-iface FILE.hs    each module of the program's interface:
         a line `TEXT key text` for each item, its text's lines apart by
         ` | `, and `FP key fingerprint` (Pickle.hash)
     rhc --dump-usages FILE.hs   each read of each unit of the program,
         `USAGE unit key => what it gives`, the entities by key *)
structure RhcIface =
struct
  structure M = HsStringMap
  structure Mo = HsModules
  structure G = RhcGraph
  structure N = RhcNames

  (* --by-interface *)
  val byInterface = ref false

  fun sortStrings xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if String.< (x, y) then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] xs
    end

  (* the interfaces of the modules `ids` from a state after their unit *)
  fun ofModules (s : N.state, ids : string list) : HsModIface.t list =
    List.map
      (fn id =>
         HsModIface.make {id = id, exports = getOpt (M.find (#exports s, id), []),
                          defs = List.filter (fn (d : Mo.def) => #home (#entity d) = id) (List.map #2 (M.listItems (#defs s))),
                          fixity = fn k => M.find (#fixities s, k), env = #types s})
      ids

  (* `recording f` is what `f ()` gives and the reads it noted, each once,
     in the order first made *)
  fun recording (f : unit -> 'a) : 'a * HsUsage.read list =
    let
      val seen = ref M.empty
      val order = ref []
      fun note r =
        let val k = HsUsage.key r
        in if M.member (!seen, k) then () else (seen := M.insert (!seen, k, ()); order := r :: !order) end
      val old = HsUsage.setNote note
      val x = f () handle e => (ignore (HsUsage.setNote old); raise e)
    in
      ignore (HsUsage.setNote old);
      (x, List.rev (!order))
    end

  fun spaceOf "t" = Mo.Type
    | spaceOf _ = Mo.Value

  (* `answer {state, fingerprint, own} r` is what the read `r` gives in
     `state`: the entities a name stands for in a module's scope, what an
     import item names of a module's exports (and their constructors,
     fields and methods), a module's exports, the instance of a class at
     a type or none, an entity's fingerprint. An entity of the unit itself
     (`own` its module) is by its key; any other with its fingerprint. *)
  fun answer {state : N.state, fingerprint : string -> string option, own : string -> bool} (r : HsUsage.read) : string =
    let
      fun ent (e : Mo.entity) =
        let val k = Mo.key e in if own (#home e) then k else k ^ "=" ^ getOpt (fingerprint k, "?") end
      fun ents es = String.concatWith " " (sortStrings (List.map ent es))
      fun exportsOf id = getOpt (M.find (#exports state, id), [])
    in
      case r of
        HsUsage.Name {within, space, qual, name} =>
          (case M.find (#scopes state, within) of
             SOME sc => ents (Mo.lookup (sc, spaceOf space, qual, name))
           | NONE => "(no scope)")
      | HsUsage.Item {from, space, name} =>
          let
            val ex = exportsOf from
            val named = List.filter (fn (e : Mo.entity) => #space e = spaceOf space andalso #name e = name) ex
            fun under (e : Mo.entity) =
              case M.find (#defs state, Mo.key e) of
                SOME {parent = SOME p, ...} => List.exists (fn n => Mo.key n = Mo.key p) named
              | _ => false
          in
            ents (named @ List.filter under ex)
          end
      | HsUsage.Exports m => String.concatWith " " (sortStrings (List.map Mo.key (exportsOf m)))
      | HsUsage.Instance {cls, tycon} =>
          (case HsClasses.findInstance (HsInfer.classes (#types state), cls, tycon) of
             SOME {id, home, ...} => if own home then id else id ^ "=" ^ getOpt (fingerprint id, "?")
           | NONE => "none")
      | HsUsage.Standard {space, name} =>
          let
            val from =
              if List.exists (fn n => n = name) ["Ix", "range", "index", "inRange", "rangeSize"] then RhcLibrary.identity "Ix"
              else RhcLibrary.identity "Prelude"
          in
            ents (List.filter (fn (e : Mo.entity) => #space e = spaceOf space andalso #name e = name) (exportsOf from))
          end
      | HsUsage.Entity k => getOpt (fingerprint k, "?")
    end

  (* ---- a program by its groups, each from the interfaces before it ---- *)

  (* One group's turn: its state, from the interfaces of the groups before
     it, and its own interfaces and reads. A group after one with an error
     is named and not checked, as a whole check does. *)
  type turn = {group : G.node list, state : N.state, ifaces : HsModIface.t list, reads : HsUsage.read list}

  fun turns (g : G.graph, fixpoint, check, evidence) : turn list =
    let
      val leaves = N.leavesOf (List.concat (#groups g))
      fun start ifaces : N.state =
        let val s = N.install (N.initial leaves, ifaces)
        in
          {defs = #defs s, universe = #universe s, fixities = #fixities s, library = #library s, exports = #exports s,
           scopes = #scopes s, diags = #diags s, modules = #modules s, derived = #derived s, evidence = evidence,
           types = #types s}
        end
      fun go ([], _, _, acc) = List.rev acc
        | go (group :: rest, ifaces, failed, acc) =
            let
              val (s, reads) =
                recording (fn () => N.groups (N.extend (start ifaces, group), [group], fixpoint, if failed then NONE else check))
              val mine = ofModules (s, List.map #id group)
              val failedNow = failed orelse List.exists (fn d => not (#library d)) (#diags s)
            in
              go (rest, ifaces @ mine, failedNow, {group = group, state = s, ifaces = mine, reads = reads} :: acc)
            end
    in
      go (#groups g, [], false, [])
    end

  (* `program (g, fixpoint, check)` names and checks the program of `g`
     group by group from interfaces: the result a whole check gives *)
  fun program (g : G.graph, fixpoint, check) : N.result =
    let
      val evidence = HsEvidence.empty ()
      val ts = turns (g, fixpoint, check, evidence)
      val all = List.concat (List.map #ifaces ts)
      val final = N.install (N.initial (N.leavesOf (List.concat (#groups g))), all)
    in
      {modules = List.concat (List.map (fn {state, ...} : turn => List.rev (#modules state)) ts),
       exports = #exports final, diags = List.concat (List.map (fn {state, ...} : turn => #diags state) ts),
       types = Option.map (fn _ => #types final) check, evidence = evidence,
       derived = List.concat (List.map (fn {state, ...} : turn => #derived state) ts)}
    end

  (* ---- the dumps ---- *)

  fun programModules (g : G.graph) =
    List.filter (fn grp => not (List.all #library grp)) (#groups g)

  fun dumpIface (g : G.graph, fixpoint, check) =
    let
      val ts = turns (g, fixpoint, check, HsEvidence.empty ())
      val fps : string M.map ref = ref M.empty
      fun escape t = String.concatWith " | " (String.fields (fn c => c = #"\n") t)
    in
      List.app
        (fn {group, ifaces, ...} : turn =>
           List.app
             (fn (i : HsModIface.t) =>
                let
                  val mine = HsModIface.fingerprints Pickle.hash (i, fn k => M.find (!fps, k))
                  val () = fps := List.foldl (fn ((k, f), m) => M.insert (m, k, f)) (!fps) mine
                in
                  if List.all #library group then ()
                  else
                    (print ("IFACE\t" ^ #id i ^ "\n");
                     List.app (fn (k, t) => print ("TEXT\t" ^ k ^ "\t" ^ escape t ^ "\n")) (HsModIface.canonical i);
                     List.app (fn (k, f) => print ("FP\t" ^ k ^ "\t" ^ f ^ "\n")) mine)
                end)
             ifaces)
        ts
    end

  fun dumpUsages (g : G.graph, fixpoint, check) =
    List.app
      (fn {group, state, reads, ...} : turn =>
         if List.all #library group then ()
         else
           let
             val ids = List.map #id group
             val unit = String.concatWith "," ids
           in
             List.app (fn r => print ("USAGE\t" ^ unit ^ "\t" ^ HsUsage.key r ^ " => " ^
                                      answer {state = state, fingerprint = fn _ => NONE, own = fn _ => true} r ^ "\n"))
               reads
           end)
      (turns (g, fixpoint, check, HsEvidence.empty ()))
end
