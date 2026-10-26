(* The rules of the checks that no program the compiler makes breaks, each
   refused where it is broken by hand (tests/runner/tools.sml,
   compiler/lint-rules):
   * a check moves none of the compiler's counters of names (Pass.checkAt);
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
     reps = Vector.tabulate (10, fn _ => RAny)}
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
    (Pass.checkAt "test" check (); report (what, wanted = "", "accepted"))
    handle Error.Bug m => report (what, wanted <> "" andalso String.isSubstring wanted m, "refused: " ^ m)

  fun main () =
    (checked ("counters: a check that takes no name", fn () => ignore (Ty.con (7, "t", [])), "");
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
