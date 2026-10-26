(* The rules of the checks that no program the compiler makes breaks, each
   refused where it is broken by hand (tests/runner/tools.sml,
   compiler/lint-rules) -- those no fault made after a stage reaches
   (RUNE_FAULT; the jobs faults/STAGE:KIND), which are the rest's negative tests:
   * LambdaLint's, MidLint's, LowLint's and the renaming's (M4), with
     what is near each taken: constants at each end of their range, the
     casts by origin, an exception's payload and a copy's, a Do's globals;
   * a check moves none of the compiler's counters of names (Pass.checkAt),
     and runs from its level up (M3);
   * a part of a program checked in its context (MidLint.checkIn, inside
     simplify) and a unit's code read back (Pipeline.codeRoundTrip; M3);
   * LowLint's rule of what is defined on every way to a use, by dominance,
     and midcanon's renaming (MidCanon.checkRenaming; linting roadmap, M2);
   * the invariant of results in globals (LowLint.results; docs/ir.md, What
     a Low keeps), on Low made by hand: what Lower makes of results is
     taken, and every breach of each of its rules is refused. The facts: f1
     and f2 (globals 101 and 102) return 3 fields, fields 1 and 2 in
     globals 501 and 502, which some call reads; f3 (global 103) returns
     its datatype in globals 601 and 602; f4 (global 104) returns as any
     function does. *)
structure LintRulesTest =
struct
  open Low

  val facts : LowLint.results =
    {global = fn f => if f >= 1 andalso f <= 4 then SOME (100 + f) else NONE,
     fields = fn g => if g = 101 orelse g = 102 then SOME 3 else NONE,
     slots = fn n => if n = 3 then [501, 502] else [],
     needed = fn (n, i) => n = 3 andalso (i = 1 orelse i = 2),
     sum = fn g => if g = 103 then SOME [601, 602] else NONE}

  fun func (id, blocks) : func =
    {id = id, name = "f" ^ Int.toString id, params = [0], ncaptured = 0, nvars = 10, blocks = blocks, pos = NONE,
     reps = Vector.tabulate (10, fn _ => RAny), result = RAny, captures = []}
  fun block (label, instrs, transfer) : block = {label = label, params = [], instrs = instrs, transfer = transfer}
  val here : pos = (Source.noSpan, [])

  (* f1 returns its first field, the others set; the top level calls f1,
     and f3, and reads what each left *)
  val f1 = func (1, [block (0, [Def (1, Unit), Def (2, SetGlobal (501, 1)), Def (3, SetGlobal (502, 1))], Return 1)])
  val top = func (0, [block (0, [Def (1, Unit), Def (2, CallK (1, [1])), At here, Def (3, Slot 501), Def (4, Slot 502),
                                 Def (5, CallK (3, [1])), Def (6, Slot 601)], Return 1)])
  fun f2 (instrs, transfer) = func (2, [block (0, Def (1, Unit) :: instrs, transfer)])

  val failed = ref 0
  fun report (what, ok, detail) =
    if ok then print ("PASS lint-rules: " ^ what ^ "\n")
    else (failed := !failed + 1; print ("FAIL lint-rules: " ^ what ^ ": " ^ detail ^ "\n"))
  fun accepted (what, p) =
    (LowLint.results facts p; report (what, true, ""))
    handle Error.Bug m => report (what, false, "refused: " ^ m)
  fun refused (what, p, wanted) =
    (LowLint.results facts p; report (what, false, "accepted"))
    handle Error.Bug m => report (what, String.isSubstring wanted m, "refused otherwise: " ^ m)

  fun checked (what, check, wanted) =
    (Pass.checkAt ("test", 0) check (); report (what, wanted = "", "accepted"))
    handle Error.Bug m => report (what, wanted <> "" andalso String.isSubstring wanted m, "refused: " ^ m)

  (* ---- LowLint's ways: what is defined on every way to a use, by
     dominance (M2); one function, its blocks as given *)
  fun low (what, blocks, wanted) = checked ("low: " ^ what, fn () => LowLint.check [func (0, blocks)], wanted)
  fun blockP (label, params, instrs, transfer) : block = {label = label, params = params, instrs = instrs, transfer = transfer}
  val notOnEvery = "is used where it is not defined on every way"
  fun lowWays () =
    (low ("a diamond, what its head defines used after it",
          [block (0, [Def (1, Unit)], If (1, 1, 2)), block (1, [Def (2, Unit)], Goto (3, [])), block (2, [], Goto (3, [])),
           block (3, [], Return 1)], "");
     low ("a diamond, what one side defines used after it",
          [block (0, [Def (1, Unit)], If (1, 1, 2)), block (1, [Def (2, Unit)], Goto (3, [])), block (2, [], Goto (3, [])),
           block (3, [], Return 2)], notOnEvery);
     low ("a use before its definition", [block (0, [Def (1, Select (0, 2)), Def (2, Unit)], Return 1)], notOnEvery);
     low ("a block's parameter, given by every jump",
          [block (0, [Def (1, Unit)], If (1, 1, 2)), block (1, [], Goto (3, [1])), block (2, [], Goto (3, [1])),
           blockP (3, [4], [], Return 4)], "");
     low ("a handler, what was defined before its push",
          [block (0, [Def (1, Unit), Push 2, Def (3, Unit), Pop], Goto (1, [])), block (1, [], Return 3),
           blockP (2, [4], [], Return 1)], "");
     low ("a handler, what was defined after its push",
          [block (0, [Def (1, Unit), Push 2, Def (3, Unit), Pop], Goto (1, [])), block (1, [], Return 3),
           blockP (2, [4], [], Return 3)], notOnEvery);
     low ("a block reached with handlers and without",
          [block (0, [Def (1, Unit)], If (1, 1, 2)), block (1, [Push 4], Goto (3, [])), block (2, [], Goto (3, [])),
           block (3, [], Return 1), blockP (4, [5], [], Return 5)], "is reached with");
     low ("a jump back to a loop's head, what reaches it defined",
          [block (0, [Def (1, Unit)], Goto (1, [])), block (1, [Def (2, Unit)], If (1, 1, 2)), block (2, [], Return 2)], "");
     low ("a jump back to a head from where what reaches it is not defined",
          [block (0, [Def (1, Unit)], If (1, 1, 3)), block (1, [Def (2, Unit)], Goto (2, [])), block (2, [], Return 1),
           block (3, [], Goto (2, []))], "which the jump has not");
     low ("a jump back to a block nothing reached",
          [block (0, [], Goto (2, [])), block (1, [], Return 0), block (2, [], Goto (1, []))], "which nothing reached before");
     low ("dead code, unchecked", [block (0, [], Return 0), block (1, [], Return 9)], ""))

  (* ---- midcanon's renaming (M2): what midcanon made of a program taken,
     and every way of renaming otherwise refused *)
  structure M = Mid
  val dt = 900001
  val () = Ty.bindDatatypeDirect (dt, {params = [], cons = [(0, "A", NONE), (1, "B", SOME Ty.int)]})
  val dty = Ty.con (dt, "t", [])
  val one = M.Const (Lambda.CInt (IntInf.fromInt 1), Ty.int)
  (* g1 = let v2 = 1 in let v3 = B v2 in v3; g4 = A *)
  fun prog (g1, v2, v3, g4, c, t) =
    [M.Val (g1, ([], t), M.Let (v2, ([], Ty.int), M.Atom c, M.Let (v3, ([], t), M.Con (1, t, M.Var (v2, [])), M.Return (M.Atom (M.Var (v3, [])))))),
     M.Val (g4, ([], t), M.Return (M.Atom (M.Con0 (0, t))))]
  val p = prog (11, 12, 13, 14, one, dty)
  fun renaming (what, p', wanted) = checked ("midcanon: " ^ what, fn () => MidCanon.checkRenaming p p', wanted)
  fun renamings () =
    let
      val p' = MidCanon.program p
      val dty' = case p' of M.Val (_, (_, t), _) :: _ => t | _ => dty
    in
      renaming ("what midcanon makes", p', "");
      renaming ("the program itself", p, "");
      renaming ("a name renamed two ways",
                [M.Val (21, ([], dty'), M.Let (22, ([], Ty.int), M.Atom one,
                                               M.Let (23, ([], dty'), M.Con (1, dty', M.Var (29, [])), M.Return (M.Atom (M.Var (23, [])))))),
                 M.Val (24, ([], dty'), M.Return (M.Atom (M.Con0 (0, dty'))))], "renamed to");
      renaming ("two names renamed one", prog (21, 22, 22, 24, one, dty'), "is the new name of");
      renaming ("a constant changed", prog (21, 22, 23, 24, M.Const (Lambda.CInt (IntInf.fromInt 2), Ty.int), dty'), "a constant changed");
      renaming ("a built-in type name renamed",
                [M.Val (21, ([], dty'), M.Let (22, ([], Ty.con (900002, "int", [])), M.Atom one,
                                               M.Let (23, ([], dty'), M.Con (1, dty', M.Var (22, [])), M.Return (M.Atom (M.Var (23, [])))))),
                 M.Val (24, ([], dty'), M.Return (M.Atom (M.Con0 (0, dty'))))], "built-in type name");
      renaming ("a datatype not entered again", prog (21, 22, 23, 24, one, Ty.con (900003, "t", [])), "not entered again");
      renaming ("a definition of another kind", [M.Funs [], M.Val (24, ([], dty'), M.Return (M.Atom (M.Con0 (0, dty'))))],
                "of another kind")
    end

  (* ---- the renaming's other rules (M4): the types, the datatypes met,
     and what no fault after midcanon reaches *)
  fun dtAs (stamp, name, cons) = (Ty.bindDatatypeDirect (stamp, {params = [], cons = cons}); Ty.con (stamp, name, []))
  val sameCons = [(0, "A", NONE), (1, "B", SOME Ty.int)]
  fun renamings2 () =
    let
      val u = dtAs (900004, "u", sameCons)
      val noArg = dtAs (900005, "t", [(0, "A", NONE), (1, "B", NONE)])
      val otherName = dtAs (900006, "t", [(0, "A", NONE), (1, "C", SOME Ty.int)])
      val pinned = dtAs (900007, "t", sameCons)
      val () = Ty.pinLayout (900007, [(0, NONE), (1, NONE)])
      val opened = dtAs (900008, "t", sameCons)
      val () = Ty.markOpen 900008
      fun with' (q, q') = fn (what, wanted) => checked ("midcanon: " ^ what, fn () => MidCanon.checkRenaming q q', wanted)
      fun one' (r, r') = with' ([M.Val (41, ([], Ty.exnCon), M.Return r)], [M.Val (51, ([], Ty.exnCon), M.Return r')])
      val here' : M.pos = (Source.noSpan, [{name = "f", site = NONE}])
    in
      renaming ("a type name renamed", prog (21, 22, 23, 24, one, u), "type name t renamed u");
      renaming ("a constructor's argument gone", prog (21, 22, 23, 24, one, noArg), "argument came or went");
      renaming ("a constructor's name changed", prog (21, 22, 23, 24, one, otherName), "a constructor's name changed");
      renaming ("a layout not fixed again", prog (21, 22, 23, 24, one, pinned), "not fixed again");
      renaming ("a datatype opened otherwise", prog (21, 22, 23, 24, one, opened), "opened otherwise");
      renaming ("a type made another",
                [M.Val (21, ([], dty), M.Let (22, ([], Ty.unit), M.Atom one,
                                              M.Let (23, ([], dty), M.Con (1, dty, M.Var (22, [])), M.Return (M.Atom (M.Var (23, [])))))),
                 M.Val (24, ([], dty), M.Return (M.Atom (M.Con0 (0, dty))))], "type int made unit");
      renaming ("an expression of another kind",
                [List.hd (prog (21, 22, 23, 24, one, dty)), M.Val (24, ([], dty), M.Raise (M.Con0 (0, dty)))], "an expression of another kind");
      one' (M.NewExn "E", M.NewExn "F") ("an exception's name changed", "an exception's name changed");
      one' (M.BuiltinExn 0, M.BuiltinExn 1) ("a built-in exception changed", "a built-in exception changed");
      with' ([M.Val (41, ([], Ty.int), M.Mark ((Source.noSpan, []), M.Return (M.Atom one)))],
             [M.Val (51, ([], Ty.int), M.Mark (here', M.Return (M.Atom one)))]) ("a position changed", "a position changed")
    end

  (* ---- LambdaLint's rules that no fault after translate reaches (M4;
     tests/runner/tools.sml, the jobs faults/translate:KIND): each refused on Lambda
     made by hand, and what is near each taken *)
  structure L = Lambda
  val i1 = L.Const (L.CInt (IntInf.fromInt 1), Ty.int)
  val s1 = L.Const (L.CString "s", Ty.string)
  fun big n = IntInf.pow (IntInf.fromInt 2, n)
  val wordTy = Ty.con (#stamp Types.wordTycon, #name Types.wordTycon, [])
  val charTy = Ty.con (#stamp Types.charTycon, #name Types.charTycon, [])
  val pairToInt = Ty.arrow (Ty.tuple [Ty.int, Ty.int], Ty.int)
  fun lam (what, e, wanted) = checked ("lambda: " ^ what, fn () => LambdaLint.check e, wanted)
  val ga = Ty.gen 77
  fun lambdaRules () =
    let
      val () = IntTable.insert (Ty.exnArgs, 70, SOME Types.intTy)
      (* a copy is registered where a lint will look, from level 1 *)
      val saved = !Pass.lintGiven
      val () = Pass.lintGiven := SOME 0
      val () = Ty.copyExn (70, 72, fn t => t)
      val () = Pass.lintGiven := SOME 1
      val () = Ty.copyExn (70, 71, fn t => t)
      val () = Pass.lintGiven := saved
    in
      lam ("branches of two types", L.If (L.trueExp, i1, s1), "where int is wanted");
      lam ("a constructor of what is no datatype", L.Con (0, Ty.unit, i1), "is no datatype");
      lam ("a function of a type that is no arrow", L.Fn (1, Ty.int, L.Unit), "a function of type int");
      lam ("an application of what is no function", L.App (i1, L.Unit), "an application of what has type int");
      lam ("a field of what is no tuple", L.Select (0, i1), "a field of what has type int");
      lam ("a nullary constructor that takes an argument", L.Con0 (1, dty), "is not nullary");
      lam ("a constructor given an argument it does not take", L.Con (0, dty, i1), "takes no argument");
      lam ("an argument taken from a nullary constructor", L.Decon (0, L.Con0 (0, dty)), "has no argument");
      lam ("the tag of what is no datatype", L.ConTag L.Unit, "the tag of what has type unit");
      lam ("a primitive of no description", L.Prim ("no_such_primitive", SOME (Ty.arrow (Ty.int, Ty.int)), [i1]), "has no description");
      lam ("int_add at its description", L.Prim ("int_add", SOME pairToInt, [i1, i1]), "");
      lam ("a primitive given three arguments for two", L.Prim ("int_add", SOME pairToInt, [i1, i1, i1]), "given 3 arguments");
      lam ("a primitive of a type that is no arrow", L.Prim ("functor_marker", SOME Ty.int, []), "primitive functor_marker of type int");
      lam ("ref_get of what is no ref", L.Prim ("ref_get", NONE, [i1]), "ref_get of what has type int");
      lam ("a primitive without a type", L.Prim ("int_add", NONE, [i1]), "without a type");
      (* constants: each kind's range *)
      lam ("the least int", L.Const (L.CInt (IntInf.~ (big 62)), Ty.int), "");
      lam ("an int past 63 bits", L.Const (L.CInt (big 62), Ty.int), "out of the range of int");
      lam ("a word below 0", L.Const (L.CWord (IntInf.fromInt ~1), wordTy), "out of the range of");
      lam ("the least Int64.int", L.Const (L.CInt64 (IntInf.~ (big 63)), Ty.int64), "");
      lam ("an Int64.int past 64 bits", L.Const (L.CInt64 (big 63), Ty.int64), "out of the range of");
      lam ("the largest Word64.word", L.Const (L.CWord64 (IntInf.- (big 64, IntInf.fromInt 1)), Ty.word64), "");
      lam ("a Word64.word past 64 bits", L.Const (L.CWord64 (big 64), Ty.word64), "out of the range of");
      lam ("a char past 255", L.Const (L.CChar 256, charTy), "out of the range of");
      lam ("a real of type int", L.Const (L.CReal "1.0", Ty.int), "a constant 1.0 of type int");
      (* the casts, by their origin *)
      lam ("an open_cast to a flat datatype", L.Prim ("open_cast", SOME (Ty.arrow (Ty.int, Ty.flat 2)), [i1]), "");
      lam ("an open_cast to a tuple of units", L.Prim ("open_cast", SOME (Ty.arrow (Ty.int, Ty.flatArg 2)), [i1]), "");
      lam ("a dynamic_cast from unit", L.Prim ("dynamic_cast", SOME (Ty.arrow (Ty.unit, Ty.int)), [L.Unit]), "");
      lam ("a functor_cast of a type that is no arrow", L.Prim ("functor_cast", SOME Ty.int, [i1]), "a functor_cast of type int");
      lam ("the program's unsafe_cast from string to int", L.Prim ("unsafe_cast", SOME (Ty.arrow (Ty.string, Ty.int)), [s1]), "");
      (* an exception's payload, and a copy's (Ty.copyExn) *)
      lam ("an exception's payload of its argument's type", L.Let (70, L.NewExn "E", L.MkExn (L.Var 70, i1)), "");
      lam ("an exception's payload of another type", L.Let (70, L.NewExn "E", L.MkExn (L.Var 70, s1)),
           "payload has type string where its argument is int");
      lam ("a copy's payload of another type", L.Let (71, L.NewExn "E", L.MkExn (L.Var 71, s1)),
           "payload has type string where its argument is int");
      lam ("a copy made at level 0, not registered", L.Let (72, L.NewExn "E", L.MkExn (L.Var 72, s1)), "");
      (* a type variable fixed where a variable is bound, by a Fn around
         it, is given as itself (M5) *)
      lam ("a polymorphic variable at an instance",
           L.Let (2, L.Fn (1, Ty.arrow (ga, ga), L.Var 1), L.Inst (L.Var 2, Ty.arrow (Ty.int, Ty.int))), "");
      lam ("a variable at its own type, where a Fn fixes its variable",
           L.Fn (1, Ty.arrow (ga, ga), L.Let (2, L.Var 1, L.Inst (L.Var 2, ga))), "");
      lam ("a variable at an instance of what a Fn around it fixes",
           L.Fn (1, Ty.arrow (ga, Ty.int), L.Let (2, L.Var 1, L.Seq (L.Inst (L.Var 2, Ty.int), i1))),
           "fixed where v2 is bound, int")
    end

  (* ---- MidLint's rules that no fault after a stage on Mid reaches (M4;
     the jobs faults/mid:KIND), and a Do's *)
  fun midP (what, q, wanted) = checked ("mid: " ^ what, fn () => MidLint.check q, wanted)
  fun valR (g, t, r) = M.Val (g, ([], t), M.Return r)
  fun midRules () =
    let
      val add = M.Prim ("int_add", pairToInt, [one, one])
      val two : M.fundef = {name = 43, tyvars = [], params = [(44, Ty.int), (45, Ty.int)], result = Ty.int, body = M.Return add}
      val unitRet = M.Return (M.Atom M.Unit)
      fun setting x = M.Let (x, ([], Ty.unit), M.SetGlobal (48, one), unitRet)
      val raising = M.Let (51, ([], Ty.exnCon), M.BuiltinExn 0,
                           M.Let (52, ([], Ty.exn), M.MkExn (M.Var (51, []), M.Unit), M.Raise (M.Var (52, []))))
      val g48 = [(48, ([], Ty.int))]
      val yes = M.Con0 (1, Ty.bool)
      val setter : M.fundef = {name = 50, tyvars = [], params = [(54, Ty.unit)], result = Ty.unit, body = setting 55}
      fun ident f : M.fundef = {name = f, tyvars = [77], params = [(f + 1, ga)], result = ga, body = M.Return (M.Atom (M.Var (f + 1, [])))}
      fun castBack t =
        [M.Val (46, ([], t), M.Let (47, ([], Ty.unit), M.Prim ("functor_cast", Ty.arrow (Ty.int, Ty.unit), [one]),
                                    M.Return (M.Prim ("functor_cast", Ty.arrow (Ty.unit, t), [M.Var (47, [])]))))]
    in
      midP ("a global defined twice", [valR (41, Ty.int, M.Atom one), valR (41, Ty.int, M.Atom one)], "is defined twice");
      midP ("a function of no parameter", [M.Funs [{name = 42, tyvars = [], params = [], result = Ty.int, body = M.Return (M.Atom one)}]],
            "has no parameter");
      midP ("a function of two parameters given both", [M.Funs [two], valR (46, Ty.int, M.App (M.Global (43, []), [one, one]))], "");
      midP ("a function of two parameters given one argument", [M.Funs [two], valR (46, Ty.int, M.App (M.Global (43, []), [one]))],
            "parameters given 1 argument");
      midP ("a function of two parameters given three", [M.Funs [two], valR (46, Ty.int, M.App (M.Global (43, []), [one, one, one]))],
            "given 3 arguments");
      midP ("an application of what is no function", [valR (46, Ty.int, M.App (one, [one]))], "an application of what has type int");
      midP ("a primitive given three arguments for two", [valR (46, Ty.int, M.Prim ("int_add", pairToInt, [one, one, one]))],
            "given 3 arguments");
      midP ("a primitive of a type that is no arrow", [valR (46, Ty.int, M.Prim ("functor_marker", Ty.int, []))],
            "primitive functor_marker of type int");
      midP ("a primitive of no description", [valR (46, Ty.int, M.Prim ("no_such_primitive", Ty.arrow (Ty.int, Ty.int), [one]))],
            "has no description");
      midP ("a field of what is no tuple", [valR (46, Ty.int, M.Select (0, one))], "a field of what has type int");
      midP ("a nullary constructor that takes an argument", [valR (46, dty, M.Atom (M.Con0 (1, dty)))], "is not nullary");
      midP ("a constructor given an argument it does not take", [valR (46, dty, M.Con (0, dty, one))], "takes no argument");
      midP ("an argument taken from a nullary constructor", [valR (46, Ty.int, M.Decon (0, dty, M.Con0 (0, dty)))], "has no argument");
      midP ("a constructor of what is no datatype", [valR (46, Ty.int, M.Con (0, Ty.unit, one))], "is no datatype");
      midP ("the tag of what is no datatype", [valR (46, Ty.int, M.ConTag M.Unit)], "the tag of what has type unit");
      midP ("a slot cast back to its type", castBack Ty.int, "");
      midP ("a slot cast back to another type", castBack Ty.string, "is cast back to string");
      (* a Do sets each global it lists on every way that returns *)
      midP ("a Do that sets its global", [M.Do (g48, setting 53)], "");
      midP ("a Do that always raises", [M.Do (g48, raising)], "");
      midP ("a Do that sets its global on both ways", [M.Do (g48, M.If (yes, setting 53, setting 56))], "");
      midP ("a Do that sets its global on one way of two", [M.Do (g48, M.If (yes, setting 53, unitRet))],
            "which a way of it that returns does not set");
      midP ("a Do whose global a handler's way does not set", [M.Do (g48, M.Handle (setting 53, 49, unitRet))], "does not set");
      midP ("a Do whose global a function sets", [M.Funs [setter], M.Do (g48, M.Return (M.App (M.Global (50, []), [M.Unit])))], "");
      (* Mid is System F: a type names only the variables its binders bind,
         each once (M5) *)
      midP ("a polymorphic function and a use of it",
            [M.Funs [ident 51], valR (46, Ty.int, M.App (M.Global (51, [Ty.int]), [one]))], "");
      midP ("a type of a variable no binder binds", [valR (46, Ty.arrow (ga, ga), M.Atom (M.Global (51, [ga]))), M.Funs [ident 51]],
            "names 'a77, which no binder around it binds");
      midP ("a function's variable bound again inside it",
            [M.Funs [{name = 51, tyvars = [77], params = [(52, ga)], result = ga,
                      body = M.Let (53, ([77], ga), M.Atom (M.Var (52, [])), M.Return (M.Atom (M.Var (53, [ga]))))}]],
            "v53 binds 'a77 again")
    end

  (* ---- the levels (M3): a check runs from its level up; one that is
     always on says so, and how to turn it off; one at a boundary, found
     below level 2, how to find the pass *)
  fun atLevel (given, key, level, wanted) =
    let
      val saved = !Pass.lintGiven
      val () = Pass.lintGiven := given
      val what = "levels: a check of level " ^ Int.toString level ^ " at "
                 ^ (case given of SOME n => if n < 0 then "off" else Int.toString n | NONE => "the default")
      val result = (Pass.checkAt (key, level) (fn () => Error.bug "a breach") (); NONE) handle Error.Bug m => SOME m
    in
      Pass.lintGiven := saved;
      case (result, wanted) of
        (NONE, NONE) => report (what, true, "")
      | (SOME m, SOME w) => report (what, String.isSubstring w m, "refused otherwise: " ^ m)
      | (NONE, SOME _) => report (what, false, "not run")
      | (SOME m, NONE) => report (what, false, "run: " ^ m)
    end
  fun levels () =
    (atLevel (SOME 0, "always", 0, SOME "--lint=off turns the check off");
     atLevel (SOME Pass.off, "always", 0, NONE);
     atLevel (SOME 0, "boundary", 1, NONE);
     atLevel (SOME 1, "boundary", 1, SOME "--lint=2 names the pass");
     atLevel (SOME 1, "pass", 2, NONE);
     atLevel (SOME 2, "pass", 2, SOME "lint after pass: ");
     atLevel (SOME 2, "deep", 3, NONE);
     atLevel (SOME 3, "deep", 3, SOME "lint after deep: ");
     report ("levels: what --lint= and RUNE_LINT say",
             List.map Pass.levelOf ["", "off", "0", "1", "2", "3", "yes"]
             = [NONE, SOME Pass.off, SOME 0, SOME 1, SOME 2, SOME 3, SOME 2], "levelOf"))

  (* ---- a part checked in a context (MidLint.checkIn, simplify-def; M3):
     the globals of the context are named and set, others are not *)
  fun parts () =
    let
      val ctx = MidLint.context [M.Val (31, ([], Ty.int), M.Return (M.Atom one))]
      fun part (what, p, wanted) = checked ("checkIn: " ^ what, fn () => MidLint.checkIn ctx p, wanted)
    in
      part ("a global of the context named", [M.Val (32, ([], Ty.int), M.Return (M.Atom (M.Global (31, []))))], "");
      part ("a global of the context set",
            [M.Do ([], M.Let (33, ([], Ty.unit), M.SetGlobal (31, one), M.Return (M.Atom M.Unit)))], "");
      part ("a global of no context named", [M.Val (32, ([], Ty.int), M.Return (M.Atom (M.Global (39, []))))],
            "global g39 is not defined");
      part ("a global of the context at another type", [M.Val (32, ([], Ty.unit), M.Return (M.Atom (M.Global (31, []))))],
            "where unit is wanted")
    end

  (* ---- a unit's code read back (Pipeline.codeRoundTrip, code-rt; M3) *)
  fun opcode n =
    let fun go i = if i >= Vector.length Opcodes.names then raise Fail ("no opcode " ^ n)
                   else if Vector.sub (Opcodes.names, i) = n then i else go (i + 1)
    in go 0 end
  fun unitOf (nlocals, items) : Link.unitCode =
    {code = {consts = [], nglobals = 0, funcs = [{id = 0, nlocals = nlocals, code = items, name = "<toplevel>", meta = NONE}],
             files = [], inlines = [], nlabels = 0, globalReps = []},
     identity = "lint-rules", provenance = NONE, globals = [], imports = [], exports = []}
  val ret = [Code.Op (opcode "UNIT", []), Code.Op (opcode "RET", [])]
  fun bytesOf u = String.concat (UnitFile.chunks (Opcodes.fingerprint, u))
  fun codes () =
    let
      val u = unitOf (0, ret)
      fun back (what, bytes, wanted) =
        checked ("code-rt: " ^ what, fn () => Pipeline.codeRoundTrip (Opcodes.fingerprint, bytes) u, wanted)
    in
      back ("a unit's own bytes", bytesOf u, "");
      back ("bytes of a unit of another number of locals", bytesOf (unitOf (1, ret)), "another number of locals");
      back ("bytes of a unit of other code", bytesOf (unitOf (0, Code.Op (opcode "UNIT", []) :: ret)), "other code");
      back ("bytes that are no unit", "not a unit", "UnitFile.read")
    end

  (* ---- LowLint's rules that no fault after lower reaches (M4;
     the jobs faults/lower:KIND): each refused on Low made by hand. funcR: a function
     with these parameters, variables, captured values, blocks and
     representations (the rest any) *)
  fun funcR (id, params, nvars, ncaptured, blocks, reps) : func =
    {id = id, name = "f" ^ Int.toString id, params = params, ncaptured = ncaptured, nvars = nvars, blocks = blocks, pos = NONE,
     reps = Vector.tabulate (nvars, fn x => case List.find (fn (y, _) => y = x) reps of SOME (_, r) => r | NONE => RAny),
     result = RAny, captures = List.tabulate (ncaptured, fn _ => RAny)}
  fun lowP (what, q, wanted) = checked ("low: " ^ what, fn () => LowLint.check q, wanted)
  val c1 = Const (Lambda.CInt (IntInf.fromInt 1))
  fun top0 instrs = func (0, [block (0, Def (1, Unit) :: instrs, Return 1)])
  fun lowRules () =
    let
      val saved = !Pass.whole
    in
      low ("a variable past the function's", [block (0, [Def (12, Unit)], Return 12)], "is no variable of it");
      low ("a block twice", [block (0, [Def (1, Unit)], Goto (1, [])), block (1, [], Return 1), block (1, [], Return 1)], "block b1 twice");
      low ("a handler of no parameter", [block (0, [Def (1, Unit), Push 2, Pop], Goto (1, [])), block (1, [], Return 1), block (2, [], Return 1)],
           "has other than one parameter");
      low ("a tail call with a handler pushed", [block (0, [Def (1, Unit), Push 1], TailCall (1, 1)), blockP (1, [2], [], Return 2)],
           "a tail call with a handler pushed");
      low ("a jump back with another number of handlers",
           [block (0, [Def (1, Unit)], Goto (1, [])), block (1, [Push 3], Goto (2, [])), block (2, [], Goto (1, [])),
            blockP (3, [4], [], Return 4)], "handlers where it has");
      lowP ("a closure of a function of two parameters", [top0 [Def (2, Closure (5, []))], funcR (5, [0, 1], 4, 0, [block (0, [], Return 0)], [])],
            "which has 2 parameters");
      lowP ("a closure of no function", [top0 [Def (2, Closure (99, []))]], "a closure of no function f99");
      lowP ("a value captured and never read", [funcR (5, [0], 4, 1, [block (0, [], Return 0)], [])], "env 0 is captured and never read");
      Pass.whole := true;
      lowP ("a known call of no function, in a whole program", [top0 [Def (2, CallK (99, [1]))]], "a known call of no function f99");
      Pass.whole := saved;
      (* representations *)
      lowP ("an argument of a primitive of another representation",
            [funcR (0, [0], 10, 0, [block (0, [Def (1, Const (Lambda.CString "s")), Def (2, Prim ("int_add", [1, 1]))], Return 2)],
                    [(1, RPtr)])], "argument 0 of int_add");
      lowP ("a field of another representation than its part",
            [funcR (0, [0], 10, 0, [block (0, [Def (1, c1), Def (2, Tuple [1, 1]), Def (3, Select (0, 2))], Return 3)],
                    [(1, RInt), (3, RPtr)])], "where field 0 of v2");
      lowP ("a block's parameter of another representation",
            [funcR (0, [0], 10, 0, [block (0, [Def (1, c1)], Goto (1, [1])), blockP (1, [2], [], Return 2)], [(1, RInt), (2, RPtr)])],
            "parameter 0 of b1");
      lowP ("a known function's parameter of another representation",
            [funcR (0, [0], 10, 0, [block (0, [Def (1, c1), Def (2, CallK (5, [1]))], Return 2)], [(1, RInt)]),
             funcR (5, [0], 4, 0, [block (0, [], Return 0)], [(0, RPtr)])], "parameter 0 of f5");
      lowP ("a handler's exception as an int",
            [funcR (0, [0], 10, 0, [block (0, [Def (1, Unit), Push 2, Pop], Goto (1, [])), block (1, [], Return 1),
                                    blockP (2, [3], [], Return 3)], [(3, RInt)])], "the exception");
      lowP ("a captured value of another representation than what reads it",
            [funcR (0, [0], 10, 0, [block (0, [Def (1, c1), Def (2, Closure (5, [SOME 1]))], Return 2)], [(1, RInt)]),
             funcR (5, [0], 4, 1, [block (0, [Def (1, Env 0)], Return 1)], [(1, RPtr)])], "env 0 of f5")
    end

  fun main () =
    (parts ();
     renamings2 ();
     lambdaRules ();
     midRules ();
     lowRules ();
     codes ();
     levels ();
     lowWays ();
     renamings ();
     checked ("counters: a check that takes no name", fn () => ignore (Ty.con (7, "t", [])), "");
     checked ("counters: a check that takes a stamp", fn () => ignore (Elaborate.freshStamp ()), "moved the compiler's counters");
     checked ("counters: a check that takes a type name", fn () => ignore (Types.freshTycon ("t", 0, false)),
              "moved the compiler's counters");
     checked ("counters: a check that takes a function's id", fn () => Lower.nextFuncId := !Lower.nextFuncId + 1,
              "moved the compiler's counters");
     accepted ("what Lower makes", [top, f1]);
     accepted ("a tail call of another of 3 fields", [f2 ([], TailCallK (1, [1]))]);
     accepted ("a return of what a call of another of 3 fields gave", [f2 ([Def (2, CallK (1, [1])), Pop], Return 2)]);
     accepted ("a function that returns as any does", [func (4, [block (0, [Def (1, Unit)], Return 1)])]);
     (* a read follows a call of a function that leaves the result there *)
     refused ("a read where no call is", [func (0, [block (0, [Def (1, Unit), Def (2, Slot 501)], Return 1)])],
              "read where no call");
     refused ("a read after a call that leaves its results elsewhere",
              [func (0, [block (0, [Def (1, Unit), Def (2, CallK (3, [1])), Def (3, Slot 501)], Return 1)])],
              "which leaves no result in it");
     refused ("a read after a call of a function of no results",
              [func (0, [block (0, [Def (1, Unit), Def (2, CallK (4, [1])), Def (3, Slot 501)], Return 1)])],
              "read where no call");
     refused ("a read with something between it and the call",
              [func (0, [block (0, [Def (1, Unit), Def (2, CallK (1, [1])), Def (3, Unit), Def (4, Slot 501)], Return 1)])],
              "read where no call");
     (* a return sets every field some call reads, after the last call *)
     refused ("a return that sets one field of two", [f2 ([Def (2, SetGlobal (501, 1))], Return 1)], "has not set g502");
     refused ("a return that sets its fields before a call",
              [f2 ([Def (2, SetGlobal (501, 1)), Def (3, SetGlobal (502, 1)), Def (4, CallK (4, [1]))], Return 1)],
              "has not set g501");
     refused ("a return of what a call of another kind gave", [f2 ([Def (2, CallK (4, [1]))], Return 2)], "has not set");
     refused ("a return of an earlier call's result",
              [f2 ([Def (2, CallK (1, [1])), Def (3, CallK (4, [1]))], Return 2)], "has not set");
     (* it calls in tail position only another of its fields, and never through a closure *)
     refused ("a tail call of a function of no results", [f2 ([], TailCallK (4, [1]))], "returns no 3 fields");
     refused ("a tail call of a function of its datatype", [f2 ([], TailCallK (3, [1]))], "returns no 3 fields");
     refused ("a tail call through a closure", [f2 ([], TailCall (1, 1))], "through a closure");
     if !failed = 0 then () else OS.Process.exit OS.Process.failure)
end
val () = LintRulesTest.main ()
