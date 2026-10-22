(* Benchmark correctness inventory. Measurements are explicit production-tool
   operations; deterministic budgets and routine checks belong to check. *)
structure Benchmarks =
struct
  open Sh
  fun fail why = (say ("FAIL benchmark: " ^ why ^ "\n"); Posix.Process.exit 0w1)
  fun protect f () = f () handle BenchmarkRun.Failed why => fail why
    | BenchmarkMeasurement.Failed why => fail why | BenchmarkExtras.Failed why => fail why
    | InventoryTests.Failed why => fail why | e => fail (General.exnMessage e)
  fun command ["bench-catalogue-faults"] = SOME (protect BenchmarkFaults.catalogue)
    | command ["bench-matrix-status"] = SOME (protect BenchmarkFaults.matrixStatus)
    | command ["bench-provenance-faults"] = SOME (protect BenchmarkFaults.provenance)
    | command ["bench-measurement-status"] = SOME (protect BenchmarkMeasurement.status)
    | command ["bench-measurement-faults"] = SOME (protect BenchmarkMeasurement.measuredFailures)
    | command ["bench-measurement-integration"] = SOME (protect BenchmarkMeasurement.integration)
    | command ["bench-budget-faults"] = SOME (BudgetFaults.one (fromRoot "bin/rune-budget.rbc"))
    | command args = case BenchChecks.command args of SOME f => SOME f | NONE =>
        case BenchmarkRun.command args of SOME f => SOME f | NONE =>
        case BenchmarkExtras.command args of SOME f => SOME f | NONE =>
        case InventoryTests.command args of SOME f => SOME (protect f) | NONE => Budgets.command args
  fun tagged tags tree = List.foldl (fn (tag, tree) => Test.tag tag tree) tree tags
  fun job name args after memory requires level =
    let val environment = case level of NONE => NONE | SOME n => SOME
              (setEnv ("RUNE_BENCH_COMPILE_OPTIONS", "-O" ^ Int.toString n)
                      (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"] (Posix.ProcEnv.environ ())))
    in Test.requires requires (Test.it name {program = "/bin/sh", args = ["sh", "-c",
          "exec \"$RUNE_TEST_ROOT\"/bin/rune-bench-check " ^ String.concatWith " " (List.map quote args)],
          env = environment, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600, cap = 0,
          cpus = 1, memory = memory, pools = [], exclusive = false, after = after, judge = failLines} : Run.command Test.tree) end
  fun nativeRequirements spec = case String.fields (fn c => c = #":") spec of
          ["native", host] => ["host:" ^ host] | ["rune", "opt"] => ["native-host"] | _ => []
  fun catalogueTree () =
    let val active = env ("BENCH_CATALOG_ACTIVE", "0") = "1"
        val routine = not active orelse env ("BENCH_ROUTINE", "0") = "1"
        val profile = if routine then "smoke" else env ("BENCH_PROFILE", "smoke")
        val rows = BenchmarkRun.selected routine profile (if active then env ("BENCH_FILTER", "") else "")
        val configs = if active then MatrixModel.expand (env ("BENCH_CONFIGS", "rune,hosts")) else ["rune"]
        val () = if null rows then raise Fail "no benchmark catalogue row matches" else ()
        fun row (r : BenchCatalog.entry) = Test.describe (#name r)
          (List.map (fn spec => job (MatrixSuite.path spec) ["bench-catalogue-case", #name r, profile, spec] []
                          (Int.max (100, #memory r div 1024)) (nativeRequirements spec) (if active then NONE else SOME 2)) configs)
        val tags = if active then ["benchmark-catalogue"] else ["check", "bench-smoke", "bench-routine"]
    in tagged ("covers:examples/benchmarks/*" :: tags) (Test.describe "benchmark-catalogue" (List.map row rows)) end
  fun tree () =
    let val validation = job "catalogue-valid" ["bench-catalogue-validate"] [] 500 [] NONE
        val routineFaults = List.map (fn (name, args, requires) => job name args [] 1000 requires NONE)
            [("catalogue-faults", ["bench-catalogue-faults"], []),
             ("matrix-status", ["bench-matrix-status"], []),
             ("measurement-status", ["bench-measurement-status"], [])]
        val special = [job "provenance" ["bench-provenance-faults"] [] 1000 ["sha256sum"] NONE,
                       job "measurement-faults" ["bench-measurement-faults"] [] 1000 [] NONE,
                       job "measurement-integration" ["bench-measurement-integration"] [] 1000 [] NONE]
        val negative = List.map (fn name => job ("negative/" ^ name) ["bench-negative", name] [] 1000
                   (if name = "poly-memory" then ["host:polyml"] else []) NONE)
                      ["wrong-result", "wrong-name", "false-success", "timeout", "memory", "compile-error", "poly-memory"]
        val states = List.map (fn name => job ("state/" ^ name) ["bench-state", name] [] 1000 [] NONE)
                            ["simple", "kitsimple", "simple-smlnj"]
        val oracles = List.map (fn name => job ("oracle/" ^ name) ["bench-oracle", name] [] 1000 ["python3"] NONE) ["smith", "kb", "latency"]
        fun extra (name, configs) = List.map (fn spec => job ("extra/" ^ name ^ "/" ^ MatrixSuite.path spec)
                    ["bench-extra", name, spec] [] 4000 (nativeRequirements spec) NONE) (MatrixModel.expand configs)
        val extras = List.concat (List.map (fn name => extra (name, env ("BENCH_CONFIGS", "rune,hosts")))
                          ["checksum", "md5", "numerical", "render", "ppm", "vliw"])
                     @ extra ("measurement", "rune,native:mlton,native:smlnj-legacy,native:polyml")
                     @ extra ("semantics", "rune,hosts")
        val inventory = List.map (fn row => let val name = InventoryTests.string (InventoryTests.field "name" row)
                 in job name ["inventory-one", name] [] 300 [] NONE end) (InventoryTests.cases ())
    in Test.describe ""
       [Budgets.tree (), BenchChecks.tree (), catalogueTree (),
        tagged ["check", "bench-smoke", "covers:tests/benchmarks/*"] (Test.describe "benchmark-controller" (validation :: routineFaults)),
        tagged ["benchmark-extra-checks", "covers:tests/benchmarks/*"] (Test.describe "benchmark-controller" (special @ negative @ states @ oracles @ extras)),
        tagged ["benchmark-inventory-tests", "covers:tools/generate/inventory*.sml", "covers:tests/runner/inventory-cases.json"]
             (Test.describe "benchmark-inventory" (job "controller-faults" ["inventory-faults"] [] 500 [] NONE :: inventory)),
        tagged ["check", "quick", "covers:tests/perf/*"] (Test.describe "benchmark-controller" [job "budget-faults" ["bench-budget-faults"] [] 300 [] NONE])]
    end
end
