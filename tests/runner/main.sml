(* The inventory of bin/rune-test (docs/plans/unit-testing.md, M3 and M4):
   every test the runner knows, as one tree. `make check` is `make
   check-tools` and then `bin/rune-test run --tier check`.

   The programs of tests/lang and tests/errors are the runner's own tests,
   in every way make check ran them (tests/runner/lang.sml). The rest of
   what the old recipe of `make check` ran is a step each, an opaque `make`
   of its target. make check-tools builds what any of them needs before the
   runner starts, so that no two steps build one file at once; then the
   edges and pools below keep apart the steps that share files (the audit
   of M3):

   - the pool `lang`: the steps that run the programs of tests/lang from the
     root of the tree, and so write the files those programs write at fixed
     paths (tests/out/rt.*.img, basis.*.tmp). They run one at a time, each
     on most of the machine;
   - the pool `matrix`: the steps that rewrite tests/out/matrix/report.md
     and timings.tsv;
   - the pool `heap_test`: the steps that build and run build/heap_test;
   - test-opt and test-native-steps read the stack compiler's bytecode in
     tests/out and test-basis's in tests/out/matrix/rune: they wait for
     them.

   Every other step writes only a directory of its own under tests/out, and
   runs beside the rest. A step is told its CPUs as JOBS, from
   RUNE_TEST_CPUS. *)
structure Inventory =
struct
  val processors = Runtime.processors ()
  (* the CPUs of a step of the pool lang, of another step that keeps many
     busy, and of a step with -j of its own that keeps a few *)
  val wide = Int.max (1, processors * 3 div 4)
  val half = Int.max (1, processors div 2)
  val few = Int.max (1, Int.min (4, processors div 4))

  (* the lines of a file that say what failed, the last 15 of them, or the
     file's last lines *)
  fun lines file =
    let val s = TextIO.openIn file
    in String.fields (fn c => c = #"\n") (TextIO.inputAll s) before TextIO.closeIn s end
    handle IO.Io _ => []
  fun last (n, xs) = List.drop (xs, Int.max (0, length xs - n))
  fun failing xs =
    List.filter (fn l => String.isPrefix "FAIL" l orelse String.isSubstring " FAIL" l orelse String.isSubstring "Error" l
                         orelse String.isSubstring "error:" l orelse String.isPrefix "*** " l) xs

  (* a step passes when its make exits with 0; otherwise the reason is what
     its output says failed *)
  fun judge (r : Supervisor.result, files as {stdout, stderr}) =
    case Run.exitZero (r, files) of
      NONE => NONE
    | SOME (verdict, reason) =>
        let
          val said = last (15, failing (lines stdout @ lines stderr))
          val head = case String.fields (fn c => c = #"\n") reason of l :: _ => l | [] => reason
        in
          if null said then SOME (verdict, reason)
          else SOME (verdict, head ^ "\n" ^ String.concatWith "\n" said)
        end

  fun step (target, {cpus, memory, pools, after}) =
    Test.tag "check"
      (Test.it target
         {program = "/bin/sh",
          args = ["sh", "-c", "exec \"${MAKE:-make}\" --no-print-directory " ^ target ^ " JOBS=\"$RUNE_TEST_CPUS\""],
          env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600, cap = 0, cpus = cpus,
          memory = memory, pools = pools, exclusive = false, after = after,
          judge = judge} : Run.command Test.tree)

  fun lang (target, more, after) = step (target, {cpus = wide, memory = 2000, pools = "lang" :: more, after = after})
  fun alone target = step (target, {cpus = 1, memory = 500, pools = [], after = []})
  fun some target = step (target, {cpus = few, memory = 500, pools = [], after = []})

  val make =
    Test.describe "make"
      [lang ("test-opt", [], ["compile/stack-done", "make/test-basis"]),
       lang ("check-levels", [], []),
       lang ("check-units", [], []),
       lang ("test-native-steps", ["matrix"], ["compile/stack-done", "make/test-basis"]),
       lang ("test-register-steps", ["matrix"], []),
       lang ("check-cross", [], []),
       step ("test-register-jit-steps", {cpus = half, memory = 1000, pools = ["matrix"], after = []}),
       step ("test-steps", {cpus = 1, memory = 500, pools = ["heap_test"], after = []}),
       step ("test-heap-steps", {cpus = 1, memory = 500, pools = ["heap_test"], after = []}),
       alone "test-all-steps",
       step ("test-basis", {cpus = few, memory = 1000, pools = ["matrix"], after = []}),
       some "test-laws",
       some "check-positions",
       some "check-docs",
       step ("check-reproducible", {cpus = Int.min (2, few), memory = 500, pools = [], after = []}),
       step ("check-layouts", {cpus = Int.min (2, few), memory = 500, pools = [], after = []}),
       alone "bootstrap",
       alone "test-doc",
       alone "test-lib",
       alone "test-ir",
       alone "test-incremental",
       alone "test-deps",
       alone "test-dynamic",
       alone "test-build",
       alone "test-install",
       alone "test-serve",
       alone "test-repl",
       alone "test-terminal",
       alone "test-diagnostics",
       alone "test-repl-protocol",
       alone "test-kernel",
       alone "test-dap",
       alone "test-census",
       alone "check-heapsim",
       alone "check-gcsim",
       alone "check-gcbench",
       alone "perf-check",
       alone "bench-smoke",
       alone "check-isa"]

  val tests = Test.describe "" [make, Lang.tests, Canary.tests]
end

val () = Cli.main Inventory.tests
