structure BenchmarkMain =
struct
  open Sh
  exception Usage of string
  fun run tier filter changes =
    let val vm = fromRoot "bin/runevm"
        val environment = List.foldl (fn ((key, value), e) => setEnv (key, value) e) (Posix.ProcEnv.environ ()) changes
    in Posix.Process.exece (vm, [vm, fromRoot "bin/rune-test.rbc", "run", "--tier", tier]
               @ (if filter = "" then [] else [filter]), environment) end
  fun catalogue args =
    let val changes = ref [("BENCH_CATALOG_ACTIVE", "1")]
        fun set key value = changes := (key, value) :: List.filter (fn (name, _) => name <> key) (!changes)
        fun parse [] = ()
          | parse ("--profile" :: value :: rest) = (set "BENCH_PROFILE" value; parse rest)
          | parse ("--configs" :: value :: rest) = (set "BENCH_CONFIGS" value; parse rest)
          | parse ("--filter" :: value :: rest) = (set "BENCH_FILTER" value; parse rest)
          | parse ("--routine" :: rest) = (set "BENCH_ROUTINE" "1"; set "BENCH_PROFILE" "smoke"; parse rest)
          | parse _ = raise Usage "catalogue [--routine] [--profile PROFILE] [--configs CONFIGS] [--filter TEXT]"
        val () = parse args
    in run "benchmark-catalogue" "" (!changes) end
  fun main ["suite", name] =
        if List.exists (fn group : BenchCases.group => #name group = name) (BenchCases.readGroups ())
        then run "benchmark-checks" ("benchmark-checks/" ^ name ^ "/*") [] else raise Usage ("unknown benchmark suite " ^ name)
    | main ("catalogue" :: args) = catalogue args
    | main ["inventory"] = run "benchmark-inventory-tests" "" []
    | main ["smoke"] = run "bench-smoke" "" []
    | main ["extra"] = run "benchmark-extra-checks" "" []
    | main ("budgets" :: args) = Budgets.main args
    | main _ = raise Usage "suite NAME | catalogue [OPTIONS] | inventory | smoke | extra | budgets [OPTIONS]"
end
val () = case Benchmarks.command (CommandLine.arguments ()) of SOME action => action ()
 | NONE => (BenchmarkMain.main (CommandLine.arguments ()) handle BenchmarkMain.Usage message =>
       (TextIO.output (TextIO.stdErr, "rune-bench-check: " ^ message ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w2))
