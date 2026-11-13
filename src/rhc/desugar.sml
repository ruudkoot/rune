(* rhc's desugaring of a checked program (the haskell98 roadmap's M15): the
   modules RhcNames resolved and checked, every module of the program and
   of the library it reaches, made Core by HsDesugar, a unit for each of
   the graph's strongly connected groups in order (M21), with what of
   rhc's runtime (CoreRuntime) it reaches linked after it.

   A driver over units (M21f; bin/rhc's compile against its snapshot,
   RhcDriver) desugars one group at a time after the interfaces of those
   before it (`unit`), the library's taken from the snapshot: what main
   reaches of them is the Core `program` gives, the whole way. *)
structure RhcDesugar =
struct
  structure M = HsStringMap
  structure Mo = HsModules

  fun spaceOf "t" = Mo.Type
    | spaceOf _ = Mo.Value

  (* what HsDesugar is given of the checking `r` *)
  fun given (r : RhcNames.result) =
    let
      val infer = case #types r of SOME e => e | NONE => raise Fail "RhcDesugar: a program not checked"
      fun exportsOf id = getOpt (M.find (#exports r, id), [])
      (* what the Prelude exports, which the translations name *)
      fun prelude (space, name) =
        Option.map Mo.key (List.find (fn (e : Mo.entity) => #space e = spaceOf space andalso #name e = name)
                             (exportsOf (RhcLibrary.identity "Prelude")))
      fun entity (space, m, name) = Mo.key {space = spaceOf space, home = RhcLibrary.identity m, name = name}
    in
      {modules = List.map (fn (n : RhcGraph.node, m) => {id = #id n, ast = m, library = #library n}) (#modules r),
       infer = infer, evidence = #evidence r, derived = #derived r, prelude = prelude, entity = entity}
    end

  (* the graph's strongly connected groups, by the modules' identities, in
     order *)
  fun groupsOf (g : RhcGraph.graph) = List.map (List.map (fn (n : RhcGraph.node) => #id n)) (#groups g)

  fun leaves () = List.map (fn (l, names) => (RhcLibrary.identity l, names)) RhcLibrary.leaves

  (* the key of the program's main: what Main exports by the name, wherever
     it is defined (5: Main may import it and export it again) *)
  fun mainOf (g : RhcGraph.graph, r : RhcNames.result) =
    let val root = hd (#roots g)
    in
      case List.find (fn (e : Mo.entity) => #space e = Mo.Value andalso #name e = "main")
             (getOpt (M.find (#exports r, root), [])) of
        SOME e => Mo.key e
      | NONE => Mo.key {space = Mo.Value, home = root, name = "main"}
    end

  (* --desugar-units: `program` a unit at a time (`unit`), the units joined
     (CoreUnits.join), every value of each kept: the way a driver over
     units goes (M21f), for its tests *)
  val byUnits = ref false

  (* `program (g, r, strings)` is the Core program of the program of the
     graph `g`, checked as `r`, its string literals unpacked as `strings`
     says (D24) *)
  fun whole (g : RhcGraph.graph, r : RhcNames.result, strings : CoreRuntime.strings) : Core.program =
    let
      val {modules, infer, evidence, derived, prelude, entity} = given r
    in
      CoreRuntime.link strings
        (HsDesugar.program
           {modules = modules, groups = groupsOf g, infer = infer, evidence = evidence, derived = derived,
            prelude = prelude, entity = entity, runtime = CoreRuntime.program strings, leaves = leaves (),
            main = mainOf (g, r)})
    end

  (* `unit (interfaces, group, g, r)` is the Core of the unit of the modules
     `group` (identities) of the graph `g` checked as `r`, after the units of
     `interfaces`, and its interface; Core's `main` is in the unit that
     defines the program's, where `g` is a program's *)
  fun unit (interfaces : HsDesugar.interface list, group : string list, g : RhcGraph.graph, r : RhcNames.result)
      : Core.program * HsDesugar.interface =
    let
      val {modules, infer, evidence, derived, prelude, entity} = given r
      val ids = List.foldl (fn (id, s) => M.insert (s, id, ())) M.empty group
      val main =
        case #roots g of
          root :: _ => if HsModules.moduleName root = "Main" then SOME (mainOf (g, r)) else NONE
        | [] => NONE
    in
      HsDesugar.unit
        {interfaces = interfaces, modules = List.filter (fn (m : HsDesugar.module_) => M.member (ids, #id m)) modules,
         infer = infer, evidence = evidence, derived = derived, prelude = prelude, entity = entity,
         runtime = CoreRuntime.program CoreRuntime.Lazy, leaves = leaves (), main = main}
    end

  (* the program a unit at a time, each group of `g` that holds a module of
     `r` after the interfaces of those before it, the units joined; at
     level 2 each unit's Core is held to CoreLint alone, after the runtime's
     interface, as a unit file is compiled *)
  fun byUnit (g : RhcGraph.graph, r : RhcNames.result, strings : CoreRuntime.strings) : Core.program =
    let
      val present = List.foldl (fn ((n : RhcGraph.node, _), s) => M.insert (s, #id n, ())) M.empty (#modules r)
      val runtime = CoreRuntime.program strings
      val runtimeIface =
        CoreUnits.interface (runtime, List.mapPartial (fn Core.Val (x, _, _) => SOME x | Core.Data (t, _, _) => SOME t
                                                        | Core.Newtype (t, _, _, _) => SOME t | Core.Import _ => NONE)
                                        runtime)
      fun alone (p, group) =
        Pass.checkAt ("units", 2)
          (fn p => CoreLint.check (CoreUnits.join [runtimeIface, p])
                   handle CoreLint.Error msg => raise Error.Bug ("the unit of " ^ String.concatWith " " group
                                                                 ^ ", its Core alone: " ^ msg))
          p
      fun go ([], _, acc) = List.rev acc
        | go (group :: groups, interfaces, acc) =
            if List.exists (fn id => M.member (present, id)) group then
              let val (p, i) = unit (interfaces, group, g, r)
              in alone (p, group); go (groups, interfaces @ [i], p :: acc) end
            else go (groups, interfaces, acc)
    in
      CoreRuntime.link strings (CoreUnits.join (go (groupsOf g, [], [])))
    end

  fun program (g, r, strings) = if !byUnits then byUnit (g, r, strings) else whole (g, r, strings)
end
