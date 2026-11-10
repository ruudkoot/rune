(* rhc's desugaring of a checked program (the haskell98 roadmap's M15): the
   modules RhcNames resolved and checked, every module of the program and
   of the library it reaches, made Core by HsDesugar, with what of rhc's
   runtime (CoreRuntime) it reaches linked after it. *)
structure RhcDesugar =
struct
  structure M = HsStringMap
  structure Mo = HsModules

  fun spaceOf "t" = Mo.Type
    | spaceOf _ = Mo.Value

  (* `program (g, r, strings)` is the Core program of the program of the
     graph `g`, checked as `r`, its string literals unpacked as `strings`
     says (D24) *)
  fun program (g : RhcGraph.graph, r : RhcNames.result, strings : CoreRuntime.strings) : Core.program =
    let
      val infer = case #types r of SOME e => e | NONE => raise Fail "RhcDesugar: a program not checked"
      fun exportsOf id = getOpt (M.find (#exports r, id), [])
      (* what the Prelude exports, which the translations name *)
      fun prelude (space, name) =
        Option.map Mo.key (List.find (fn (e : Mo.entity) => #space e = spaceOf space andalso #name e = name)
                             (exportsOf (RhcLibrary.identity "Prelude")))
      fun entity (space, m, name) = Mo.key {space = spaceOf space, home = RhcLibrary.identity m, name = name}
      val runtime = CoreRuntime.program strings
      val p =
        HsDesugar.program
          {modules = List.map (fn (n : RhcGraph.node, m) => {id = #id n, ast = m, library = #library n}) (#modules r),
           infer = infer, evidence = #evidence r, prelude = prelude, entity = entity, runtime = runtime,
           leaves = List.map (fn (l, names) => (RhcLibrary.identity l, names)) RhcLibrary.leaves,
           main = Mo.key {space = Mo.Value, home = hd (#roots g), name = "main"}}
    in
      CoreRuntime.link strings p
    end
end
