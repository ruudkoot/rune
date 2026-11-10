(* rhc's desugaring of a checked program (the haskell98 roadmap's M15): the
   modules RhcNames resolved and checked, every module of the program and
   of the library it reaches, made Core by HsDesugar, with what of rhc's
   runtime (CoreRuntime) it reaches linked after it.

   A saved world (RhcWorld, D45's B) may hold the library's part of the
   desugaring, made once (`library`), and desugar each program's own
   modules against it (`programOn`): the Core is the same as `program`'s,
   the whole way. *)
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

  fun leaves () = List.map (fn (l, names) => (RhcLibrary.identity l, names)) RhcLibrary.leaves

  fun mainOf (g : RhcGraph.graph) = Mo.key {space = Mo.Value, home = hd (#roots g), name = "main"}

  (* `program (g, r, strings)` is the Core program of the program of the
     graph `g`, checked as `r`, its string literals unpacked as `strings`
     says (D24) *)
  fun program (g : RhcGraph.graph, r : RhcNames.result, strings : CoreRuntime.strings) : Core.program =
    let
      val {modules, infer, evidence, derived, prelude, entity} = given r
    in
      CoreRuntime.link strings
        (HsDesugar.program
           {modules = modules, infer = infer, evidence = evidence, derived = derived, prelude = prelude, entity = entity,
            runtime = CoreRuntime.program strings, leaves = leaves (), main = mainOf g})
    end

  (* `library r` is the library's part of the desugaring of `r`, the
     library checked alone (a saved world's), every body made; the
     runtime's declarations it is written against are those of either way
     of unpacking strings, which declare the same *)
  fun library (r : RhcNames.result) : HsDesugar.library =
    let
      val {modules, infer, evidence, derived, prelude, entity} = given r
      val lib =
        HsDesugar.library
          {modules = modules, infer = infer, evidence = evidence, derived = derived, prelude = prelude, entity = entity,
           runtime = CoreRuntime.program CoreRuntime.Lazy, leaves = leaves ()}
    in
      HsDesugar.prepare lib; lib
    end

  (* `programOn (lib, g, r, strings)` is `program (g, r, strings)`, the
     library's part `lib`'s *)
  fun programOn (lib : HsDesugar.library, g : RhcGraph.graph, r : RhcNames.result, strings : CoreRuntime.strings)
      : Core.program =
    let
      val {modules, infer, evidence, derived, prelude, entity} = given r
    in
      CoreRuntime.link strings
        (HsDesugar.programOn
           (lib, {modules = modules, infer = infer, evidence = evidence, derived = derived, prelude = prelude,
                  entity = entity, main = mainOf g}))
    end
end
