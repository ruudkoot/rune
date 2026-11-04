(* Loading by need where units stay loaded (the compiler library's analysis,
   docs/compiler-analysis.md, Loading by need): what truncate leaves of M6's
   tables, and the path a type prints by in a view against the one the whole
   environment gives it (the path index, Env.beyond). *)
structure LazyUnitsTests =
struct
  fun need (ok, message) = if ok then () else raise Fail message
  (* a unit elaborated in env and exported, as an analysis does: its export,
     its identity (its static layer's), and where its names start *)
  fun elaborate (env, name, text) =
    let
      val file = Source.fromString (name, text)
      val () = Source.register file
      val (ds, fx) = Parser.parseTokensWith (Lexer.tokenize file, Fixity.initial)
      val e = ref env
      val start = UnitBasis.begin (env, Fixity.initial)
      val () = Elaborate.elabTop (e, ds)
      val () = Elaborate.finish ()
      val exported = UnitBasis.export {start = start, name = name, file = name, text = fn () => text, mode = Source.Ascii,
                                       delta = !Elaborate.lastDelta, fixity = fx}
      val () = UnitBasis.undo start
    in (exported, name ^ "@" ^ #static exported, #counters start) end
  (* elaborated where env is, loaded whole and bound: env after it *)
  fun whole (env, name, text) =
    let
      val (exported, identity, at) = elaborate (env, name, text)
      val r = UnitBasis.loadKnown ({pickle = #pickle exported, sidecar = #sidecar exported, file = name, at = at}, SOME identity, [])
    in UnitBasis.bind r; (Env.plus (env, #delta r), exported, identity, r) end
  fun begin () =
    (UnitBasis.startSession (); UnitBasis.startLazy true; UnitBasis.indexPaths := true; UnitBasis.staticOnly := true;
     Elaborate.makesCode := false; Pass.whole := false; CompilerSettings.target := "registers"; Env.beyond := Env.nowhere)

  (* A unit taken out of the session (truncate) is out of M6's tables too: not
     deferred, not loaded late at its old place by a materialise, not loaded
     by need any more *)
  fun truncated () =
    let
      val () = begin ()
      val (env, _, a, _) = whole (Env.initial, "a.sml", "structure A = struct datatype t = T val x = T end\n")
      val (exported, b, _) = elaborate (env, "b.sml", "val y = A.x\n")
      val _ = UnitBasis.lightLoad ({pickle = #pickle exported, sidecar = #sidecar exported, file = "b.sml", at = UnitBasis.counters ()},
                                   b, ["v y"], [])
      val () = need (UnitBasis.isDeferred b andalso !UnitBasis.deferredCount = 1, "a unit loaded by need is deferred")
      val _ = UnitBasis.truncate [b]
      val () = need (not (UnitBasis.isDeferred b), "a unit taken out stays deferred")
      val () = need (!UnitBasis.deferredCount = 0, "a unit taken out is counted deferred")
      val () = need (not (List.exists (fn i => i = b) (!UnitBasis.lazyOrder)), "a unit taken out stays in the order of loads")
      val late = !UnitBasis.lateCount
      val () = UnitBasis.materialise [b]
      val () = need (!UnitBasis.lateCount = late andalso not (UnitBasis.isMaterialised b),
                     "a unit taken out is loaded late at its old place")
      val () = need (UnitBasis.isMaterialised a, "a unit loaded whole is not materialised")
      val _ = UnitBasis.truncate [a]
      val () = need (not (UnitBasis.isMaterialised a), "a unit taken out keeps its environment")
      val () = need (not (isSome (UnitBasis.pathsOfUnit a)), "a unit taken out keeps its paths")
    in () end

  (* every type name a structure reaches, to a depth *)
  fun tycons (env, depth) =
    let
      fun own e = StringMap.foldl (fn (Env.TyStr {fcn, ...}, acc) => case Types.fcnIsName fcn of SOME c => c :: acc | NONE => acc) [] (Env.tys e)
    in
      if depth = 0 then own env
      else own env @ List.concat (List.map (fn e => tycons (e, depth - 1)) (StringMap.listItems (Env.strs env)))
    end

  (* A type prints in a view, with what lies beyond it, as in the whole
     environment: E24's OS.Process.status that the whole prints
     RuneStatus.status, and the rest, each name of the top level in view
     alone and none; and so again with each unit taken back by need, its
     paths from the index alone *)
  val units =
    [("os.sml", "structure OS = struct structure Process = struct datatype status = Success | Failure end end\n"),
     ("rune.sml", "structure RuneStatus = struct type status = OS.Process.status end\n"),
     ("zed.sml", "structure Zed = struct datatype t = T of int structure Inner = struct datatype u = U end end\n"
                 ^ "structure Alpha = Zed\nstructure Outer = struct structure Deep = struct structure Zed = Zed end end\n"),
     ("top.sml", "type zt = Zed.Inner.u\ndatatype local' = L\nstructure Word64 = struct type word = local' end\n")]
  fun printing () =
    let
      val () = begin ()
      val (env, loaded) = List.foldl (fn ((name, text), (env, acc)) =>
                                        let val (env, exported, identity, r) = whole (env, name, text)
                                        in (env, (name, exported, identity, r) :: acc) end) (Env.initial, []) units
      val loaded = List.rev loaded
      val all = tycons (env, 4)
      val names = StringMap.listKeys (Env.strs env) @ StringMap.listKeys (Env.tys env)
      fun same (label, views) =
        List.app (fn c =>
                    let
                      val () = Env.beyond := Env.nowhere
                      val expected = Env.qualifiedName (env, c)
                    in
                      List.app (fn names =>
                                  let
                                    val view = UnitBasis.lazyView (StringMap.empty, StringMap.empty, SOME names)
                                    val got = Env.qualifiedName (view, c)
                                  in
                                    need (got = expected, label ^ ": " ^ #name c ^ " prints " ^ getOpt (got, "-") ^ " in a view of "
                                                          ^ String.concatWith "," (StringMap.listKeys names) ^ ", "
                                                          ^ getOpt (expected, "-") ^ " in the whole")
                                  end) views
                    end) all
      val views = StringMap.empty :: List.map (fn n => StringMap.insert (StringMap.empty, n, ())) names
      val () = same ("loaded whole", views)
      (* the case E24 found, which the index is for *)
      val status = valOf (List.find (fn c => #name c = "status") all)
      val () = Env.beyond := Env.nowhere
      val bare = Env.qualifiedName (UnitBasis.view (UnitBasis.initialLess (!UnitBasis.binders), StringMap.empty, StringMap.empty,
                                                    SOME (StringMap.insert (StringMap.empty, "OS", ()))), status)
      val () = need (bare = SOME "OS.Process.status" andalso Env.qualifiedName (env, status) = SOME "RuneStatus.status",
                     "a view without what lies beyond it prints OS.Process.status: " ^ getOpt (bare, "-"))
      (* each unit taken out, and back by need with the paths it had *)
      val kept = List.map (fn (name, exported, identity, r) => (name, exported, identity, UnitBasis.bindKeys r,
                                                                 valOf (UnitBasis.pathsOfUnit identity))) loaded
      val _ = UnitBasis.truncate (List.map #3 kept)
      val () = UnitBasis.binders := StringMap.empty
      val () = List.app (fn (name, exported, identity, keys, paths) =>
                           ignore (UnitBasis.lightLoad ({pickle = #pickle exported, sidecar = #sidecar exported, file = name,
                                                         at = UnitBasis.counters ()}, identity, keys, paths))) kept
      (* the same types, by their new names: the whole environment again *)
      val again = List.map (fn (_, _, identity, _, _) => identity) kept
      val () = need (List.all UnitBasis.isDeferred again, "units taken back by need are deferred")
      val viewOfAll = UnitBasis.lazyView (StringMap.empty, StringMap.empty, NONE)
      val () = Env.beyond := Env.nowhere
      val wholeAgain = Env.plus (viewOfAll, Env.empty)
      val allAgain = tycons (wholeAgain, 4)
      val () = need (length allAgain = length all, "the units taken back reach the same types")
      val () =
        List.app (fn c =>
                    let
                      val () = Env.beyond := Env.nowhere
                      val expected = Env.qualifiedName (wholeAgain, c)
                    in
                      List.app (fn names =>
                                  let
                                    val view = UnitBasis.lazyView (StringMap.empty, StringMap.empty, SOME names)
                                    val got = Env.qualifiedName (view, c)
                                  in
                                    need (got = expected, "by need: " ^ #name c ^ " prints " ^ getOpt (got, "-") ^ " in a view of "
                                                          ^ String.concatWith "," (StringMap.listKeys names) ^ ", "
                                                          ^ getOpt (expected, "-") ^ " in the whole")
                                  end) [StringMap.empty, StringMap.insert (StringMap.empty, "OS", ())]
                    end) allAgain
    in () end

  fun main () =
    let
      val () = CompilerState.withSession (CompilerState.session (), truncated)
      val () = CompilerState.withSession (CompilerState.session (), printing)
    in print "PASS compiler lazy units: truncate's tables, a type's path in a view\n" end
end
val () = LazyUnitsTests.main ()
