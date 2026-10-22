(* The repeated benchmark wrappers share one typed matrix contract. Fixtures,
   compilation levels and configuration sets are explicit job inputs. *)
structure BenchChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun select name index =
    let val group = case List.find (fn g : BenchCases.group => #name g = name) (BenchCases.readGroups ()) of
              SOME group => group | NONE => raise Failed ("unknown benchmark case " ^ name)
        val i = case Int.fromString index of SOME i => i | NONE => raise Failed "invalid benchmark mode"
        val () = need (i >= 0 andalso i < length (#modes group), "benchmark mode out of range")
    in (group, List.nth (#modes group, i)) end
  fun directory name index spec = run ^ "/benchmark-checks/" ^ name ^ "/" ^ index ^ "/" ^ MatrixSuite.path spec
  fun execute name index spec () =
    let val (group, mode) = select name index
        val () = BenchCases.validate group
        val selected = MatrixModel.expand (BenchCases.configurations group mode)
        val () = need (List.exists (fn selected => selected = spec) selected, "configuration is not selected for benchmark case")
        val dir = directory name index spec
        val () = mkdirs dir
        val config = MatrixModel.resolve {timing = false, directory = dir ^ "/resolve"} spec
        val sources = List.map fromRoot (BenchCases.sourceFiles group)
        val data = List.map (fn (path, fixture) =>
          (case fixture of BenchCases.From source => fromRoot source | BenchCases.Contents text =>
             let val source = dir ^ "/fixtures/" ^ path
             in mkdirs (OS.Path.dir source); write (source, text); source end, path)) (BenchCases.fixtures group)
        val input = case #input group of NONE => "/dev/null" | SOME path => fromRoot path
        val timeout = getOpt (#timeout mode, getOpt (Int.fromString (env ("RUNE_MATRIX_TIMEOUT", "120")), 120))
        val memory = getOpt (#memoryKiB mode, getOpt (Int.fromString (env ("RUNE_MATRIX_MEMORY", "4194304")), 4194304))
        val () = write (dir ^ "/sources.txt", String.concat (List.map (fn path => path ^ "\n") sources))
        val () = write (dir ^ "/data.txt", String.concat (List.map (fn (_, path) => path ^ "\n") data))
        val () = MatrixProgram.run {config = config, directory = dir, sources = sources,
                                   input = input, data = data, timeout = timeout, memoryKiB = memory}
    in say ("bench-" ^ name ^ ": correctness contract holds on " ^ #id config ^ "\n") end
  fun stage name index spec () =
    let val (_, mode) = select name index
        val environment = case #level mode of NONE => Posix.ProcEnv.environ ()
                     | SOME n => setEnv ("RUNE_BENCH_COMPILE_OPTIONS", "-O" ^ Int.toString n) (Posix.ProcEnv.environ ())
        val vm = fromRoot "bin/runevm"
        val payload = fromRoot (env ("RUNE_BENCH_PAYLOAD", "bin/rune-bench-check.rbc"))
    in Posix.Process.exece (vm, [vm, payload, "bench-exec", name, index, spec], environment) end
  fun report why = (say ("FAIL benchmark controller: " ^ why ^ "\n"); Posix.Process.exit 0w1)
  fun protect f () = f () handle Failed why => report why | MatrixProgram.Failed why => report why
    | MatrixLoad.Failed why => report why | MatrixPrepare.Failed why => report why
    | MatrixModel.Invalid why => report why | BenchCases.Invalid why => report why
    | e => report (General.exnMessage e)
  fun command ["bench-case", name, index, spec] = SOME (protect (stage name index spec))
    | command ["bench-exec", name, index, spec] = SOME (protect (execute name index spec))
    | command _ = NONE
  fun job (group : BenchCases.group) (i, mode : BenchCases.mode) spec =
    let val name = #name group ^ "/" ^ Int.toString i ^ "/" ^ MatrixSuite.path spec
        val memory = getOpt (#memoryKiB mode, 4194304) div 1024
        val requires = case String.fields (fn c => c = #":") spec of ["native", host] => ["host:" ^ host]
                                     | ["rune", "opt"] => ["native-host"] | _ => []
    in Test.requires requires (Test.it name {program = "/bin/sh", args = ["sh", "-c",
         "exec \"$RUNE_TEST_ROOT\"/bin/rune-bench-check bench-case " ^ quote (#name group) ^ " " ^ Int.toString i ^ " " ^ quote spec],
         env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600, cap = 0, cpus = 1,
         memory = memory, pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree) end
  fun tree () =
    let fun group (g : BenchCases.group) = List.concat (List.map (fn (i, m) =>
                  List.map (job g (i, m)) (MatrixModel.expand (BenchCases.configurations g m)))
                  (ListPair.zip (List.tabulate (length (#modes g), fn i => i), #modes g)))
    in Test.tag "benchmark-checks" (Test.tag "covers:tests/benchmarks/*" (Test.tag "covers:examples/benchmarks/*"
         (Test.describe "benchmark-checks" (List.concat (List.map group (BenchCases.readGroups ())))))) end
end
