(* The inventory of bin/rune-test (docs/plans/unit-testing.md, M3 and M4):
   every test the runner knows, as one tree. `make check` is `make
   check-tools` and then `bin/rune-test run --tier check`.

   The programs of tests/lang and tests/errors are the runner's own tests,
   in every way make check ran them (tests/runner/lang.sml), and so are the
   Basis Library suite's in make check's four configurations of Rune
   (tests/runner/basis.sml), and the laws of its documentation
   (tests/runner/laws.sml). The rest of
   what the old recipe of `make check` ran is a step each, an opaque `make`
   of its target. make check-tools builds what any of them needs before the
   runner starts, so that no two steps build one file at once; then the
   edges and pools below keep apart the steps that share files (the audit
   of M3):

   - the pool `lang`: the steps that run the programs of tests/lang from the
     root of the tree, and so write the files those programs write at fixed
     paths (tests/out/rt.*.img, basis.*.tmp). They run one at a time, each
     on most of the machine;
   - the pool `heap_test`: the steps that build and run build/heap_test;
   - test-opt reads the stack compiler's bytecode of tests/lang in tests/out
     and of the Basis suite in tests/out/matrix/rune, and test-native-steps
     the first: they wait for them.

   The profiles' extras that run tests/basis/run-matrix.sh share the pool
   `matrix`, for its report.

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

  (* a make of a target: a test of the tier check with `tags` besides, that
     covers the paths `covers` names (for --affected; a step that covers
     none is selected by every change) *)
  fun target (name, {cpus, memory, pools, after, tags, covers}) =
    List.foldl (fn (t, tree) => Test.tag t tree)
      (Test.it name
         {program = "/bin/sh",
          args = ["sh", "-c", "exec \"${MAKE:-make}\" --no-print-directory " ^ name ^ " JOBS=\"$RUNE_TEST_CPUS\""],
          env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600, cap = 0, cpus = cpus,
          memory = memory, pools = pools, exclusive = false, after = after,
          judge = judge} : Run.command Test.tree)
      (tags @ List.map (fn g => "covers:" ^ g) covers)

  fun step (name, {cpus, memory, pools, after}, tags, covers) =
    target (name, {cpus = cpus, memory = memory, pools = pools, after = after, tags = "check" :: tags, covers = covers})
  fun lang (name, more, after, covers) =
    step (name, {cpus = wide, memory = 2000, pools = "lang" :: more, after = after}, [], covers)
  fun alone (name, tags, covers) = step (name, {cpus = 1, memory = 500, pools = [], after = []}, tags, covers)
  fun some (name, tags, covers) = step (name, {cpus = few, memory = 500, pools = [], after = []}, tags, covers)

  (* what reads the programs of tests/lang, and what reads tests/perf's *)
  val langFiles = ["tests/lang/*", "tests/errors/*", "tests/opt-skip.txt"]
  val perfFiles = ["tests/perf/*"]

  val make =
    Test.describe "make"
      [lang ("test-opt", [], ["compile/stack-done", "basis-compile/stack-done"],
             langFiles @ perfFiles @ ["tests/opt/*", "tests/runtime/*", "tests/basis/*", "examples/*"]),
       alone ("check-units-steps", [], ["tests/units/*"]),
       lang ("test-native-steps", [], ["compile/stack-done"],
             langFiles @ ["tests/opt/*", "tests/basis/*", "tests/runtime/*", "examples/nqueens.sml"]),
       step ("test-register-steps", {cpus = 1, memory = 500, pools = [], after = []}, [],
             ["tests/runtime/*"]),
       step ("test-register-jit-steps", {cpus = 1, memory = 1000, pools = [], after = []}, [],
             ["tests/register/*", "tests/lang/rt.deeprec_stack.*"]),
       step ("test-steps", {cpus = 1, memory = 500, pools = ["heap_test"], after = []}, [],
             ["tests/compiler/*", "tests/runtime/*"]),
       step ("test-heap-steps", {cpus = 1, memory = 500, pools = ["heap_test"], after = []}, ["layout"], ["tests/runtime/*"]),
       alone ("test-all-steps", [], ["tests/compiler/*"]),
       some ("check-docs", ["docs"], ["*.md", "docs/*", "tests/basis/*", "lib/random/*", "lib/test/property/*"]),
       step ("check-layouts", {cpus = Int.min (2, few), memory = 500, pools = [], after = []}, ["layout"], ["tests/layouts/*"]),
       alone ("test-doc", ["quick", "docs"], ["tests/doc/*"]),
       alone ("test-lib", ["quick"], ["tests/lib/*", "lib/random/*", "lib/test/property/*"]),
       alone ("test-ir", [], ["tests/ir/*"]),
       alone ("test-incremental", [], ["tests/incremental/*", "tests/flexrec/*", "examples/hello.sml"]),
       alone ("test-deps", [], ["tests/deps/*"]),
       alone ("test-dynamic", [], ["tests/dynamic/*"]),
       alone ("test-build", [], ["tests/buildfile/*"]),
       alone ("test-install", [], ["tests/install/*", "examples/hello.sml"]),
       alone ("test-serve", [], ["tests/serve/*", "examples/hello.sml"]),
       alone ("test-repl", [], ["tests/repl/*"]),
       alone ("test-terminal", [], ["tests/terminal/*"]),
       alone ("test-diagnostics", [], ["tests/diagnostics/*", "tests/color/*"]),
       alone ("test-repl-protocol", [], ["tests/repl-protocol/*"]),
       alone ("test-kernel", [], ["tests/kernel/*"]),
       alone ("test-dap", [], ["tests/dap/*"]),
       alone ("test-census", [], perfFiles @ ["tools/heapsim/*"]),
       alone ("check-heapsim", [], ["tools/heapsim/*"]),
       alone ("check-gcsim", [], ["tools/heapsim/*"]),
       alone ("check-gcbench", [], ["tests/gcbench/*"]),
       alone ("perf-check", [], perfFiles),
       alone ("bench-smoke", [], ["examples/benchmarks/*", "tests/benchmarks/*"]),
       alone ("check-isa", [], [])]

  (* the profiles' extras (docs/testing.md, Profiles): AGENTS.md's targets
     for a kind of change, beyond make check. Each runs alone, as it always
     has: they run tests/lang from the root and the matrix *)
  fun extra (name, tags) =
    target (name, {cpus = processors, memory = 4000, pools = ["lang", "matrix"], after = [], tags = tags, covers = []})
  val extras =
    Test.describe "make"
      [extra ("test-register-asan", ["vm"]),
       extra ("test-stress", ["vm"]),
       extra ("test-windows", ["vm", "windows"]),
       extra ("test-portability", ["vm", "portability"]),
       extra ("matrix-quick", ["library"]),
       extra ("test-lib-hosts", ["library"])]

  (* each file of expectations read by the one engine (docs/testing.md,
     Expectations): it parses, and its skips name programs that are there.
     The command does nothing; the judge reads the file *)
  fun expectations (name, file, paths) =
    Test.tag "check"
      (Test.tag ("covers:" ^ file)
        (Test.it name
           {program = "/bin/sh", args = ["sh", "-c", "true"], env = NONE, dir = SOME ".", stdin = NONE,
            timeout = Time.fromSeconds 60, cap = 0, cpus = 1, memory = 10, pools = [], exclusive = false, after = [],
            judge = fn _ =>
              let
                val ls = Expectations.read file
                val stale = case paths of
                              NONE => []
                            | SOME ps => Expectations.stale (ls, {ways = [], paths = ps, used = [], today = "0000-00-00"})
              in
                case stale of
                  [] => NONE
                | _ => SOME ("FAIL", "stale: " ^ String.concatWith "\n  " (List.map Expectations.describe stale))
              end
              handle Expectations.Parse m => SOME ("FAIL", m)} : Run.command Test.tree))

  val expected =
    Test.describe "expectations"
      [expectations ("opt-skip", "tests/opt-skip.txt", SOME Lang.langPrograms),
       expectations ("basis-deviations", "tests/basis/deviations.txt", NONE),
       expectations ("windows-skip", "tests/windows-skip.txt", SOME Lang.langPrograms),
       expectations ("portability-skip", "tests/portability-skip.txt", SOME Lang.langPrograms),
       expectations ("mlton-skip", "tests/external/mlton-skip.txt", NONE),
       expectations ("lib-deviations", "tests/lib/deviations.txt", NONE)]

  val tests = Test.describe "" [make, extras, expected, Lang.tests, Basis.tree, Laws.tree, Oracles.tree, Canary.tests]
end

(* laws-one RBC STRUCTURE is the command of a job of the laws
   (tests/runner/laws.sml); every other command is the runner's *)
val () =
  case CommandLine.arguments () of
    ["laws-one", rbc, st] => Laws.one (rbc, st)
  | args => case Oracles.command args of SOME f => f () | NONE => Cli.main Inventory.tests
