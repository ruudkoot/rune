(* Small suites that add independent benchmark correctness checks. Their
   reference peers remain separate programs; the orchestration is SML. *)
structure BenchmarkExtras =
struct
  open Sh
  exception Failed of string
  fun sources name =
    let val common = ["tests/basis/harness.sml"] @ (if name = "measurement" then [] else ["examples/benchmarks/shared/input.sml"])
        val finish = ["tests/benchmarks/" ^ name ^ ".sml", "tests/basis/finish.sml"]
        val middle = case name of "numerical" => [] | "ppm" => ["examples/benchmarks/shared/ppm.sml"]
           | "render" => ["examples/benchmarks/raytrace/check.sml"]
           | "vliw" => ["examples/benchmarks/shared/files.sml", "examples/benchmarks/vliw/benchmark.sml"]
           | "checksum" => ["examples/benchmarks/checksum/benchmark.sml"]
           | "md5" => ["examples/benchmarks/md5/benchmark.sml"]
           | "semantics" => ["examples/benchmarks/shared/primes.sml", "examples/benchmarks/bdd/benchmark.sml"]
           | "measurement" => ["examples/benchmarks/shared/catalog.sml", "examples/benchmarks/shared/report.sml", "examples/benchmarks/shared/counts.sml"]
           | _ => raise Failed ("unknown additional benchmark suite " ^ name)
    in List.map fromRoot (common @ middle @ finish) end
  fun one name spec () =
    let val dir = run ^ "/benchmark-extras/" ^ name ^ "/" ^ MatrixSuite.path spec
        val () = mkdirs dir
        val config = MatrixModel.resolve {timing = false, directory = dir ^ "/resolve"} spec
    in MatrixProgram.run {config = config, directory = dir, sources = sources name, input = "/dev/null", data = [],
                          timeout = 120, memoryKiB = 4194304} end
  fun oracle name () =
    let val args = case name of "smith" => [] | "kb" => [] | "latency" => ["--check"]
                       | _ => raise Failed "unknown independent benchmark oracle"
        val dir = run ^ "/benchmark-oracles/" ^ name
        val () = mkdirs dir
        val status = Children.exec {addressSpace = SOME (1024 * 1024 * 1024), cpuTime = SOME 3600,
                                    fileSize = SOME (64 * 1024 * 1024), core = SOME 0} (fn e => e)
            {cmd = ["python3", fromRoot ("tests/benchmarks/" ^ name ^ "-oracle.py")] @ args,
             dir = SOME root, stdin = "", stdout = dir ^ "/stdout", stderr = dir ^ "/stderr", timeout = 3600}
    in if status = 0 then say (read (dir ^ "/stdout")) else
       raise Failed (name ^ " independent reference failed: " ^ firstNonEmpty (dir ^ "/stderr")) end
  fun negative name () =
    let val dir = run ^ "/benchmark-negative/" ^ name
        val () = mkdirs dir
        val tak = List.map fromRoot ["examples/benchmarks/shared/input.sml", "examples/benchmarks/shared/tak.sml",
                                   "examples/benchmarks/tak/benchmark.sml", "examples/benchmarks/shared/main.sml"]
        val (text, sources, input, seconds, memory, spec) = case name of
            "wrong-result" => ("", tak, "tak\n18 12 6 1\n999\n", 30, 1048576, "rune")
          | "wrong-name" => ("", tak, "wrong-name\n18 12 6 1\n7\n", 30, 1048576, "rune")
          | "false-success" => ("structure FalseSuccess = struct\nval _ = print \"PASS fake\\nSUMMARY 1 checks, 0 failed\\n\"\nval _ = OS.Process.exit OS.Process.failure\nend\n",
                               [], "", 30, 1048576, "rune")
          | "timeout" => ("structure Forever = struct fun loop () : unit = loop () val _ = loop () end\n",
                         [], "", 1, 1048576, "rune")
          | "memory" => ("structure MemoryPressure = struct val _ = print \"START memory\\n\" val values = Array.array (100000000,0)\nval _ = print (Int.toString (Array.length values)) end\n",
                        [], "", 30, 262144, "rune")
          | "poly-memory" => ("structure MemoryPressure = struct val _ = print \"START memory\\n\" val values = Array.array (100000000,0)\nval _ = print (Int.toString (Array.length values)) end\n",
                             [], "", 30, 262144, "native:polyml")
          | "compile-error" => ("structure Invalid = struct val value : int = true end\n", [], "", 30, 1048576, "rune")
          | _ => raise Failed "unknown benchmark negative scenario"
        val source = dir ^ "/fixture.sml"
        val () = if text = "" then () else write (source, text)
        val sources = if text = "" then sources else [source]
        val stdin = dir ^ "/input"
        val () = write (stdin, input)
        val config = MatrixModel.resolve {timing = false, directory = dir ^ "/resolve"} spec
        val ctx : MatrixLoad.context = {config = config, directory = dir, prefix = [], image = MatrixLoad.NoImage,
                    standalone = true, input = stdin, data = [], timeout = seconds, memoryKiB = memory}
        val result = MatrixLoad.load ctx (dir ^ "/program") MatrixLoad.Run sources
        val accepted = #loaded result andalso #status result = 0 andalso MatrixProgram.summary (#output result)
        val () = if accepted then raise Failed ("matrix accepted planted " ^ name) else ()
        val () = if name = "timeout" then
                    if #timedOut result then () else raise Failed "loop did not reach the runtime deadline"
                 else if name = "memory" orelse name = "poly-memory" then
                    if String.isSubstring "START memory" (#output result) then () else raise Failed "memory fixture never reached execution"
                 else ()
    in say ("PASS benchmark-negative/" ^ name ^ "\n") end
  fun protect f () = f () handle e => (say ("FAIL benchmark extras: " ^ General.exnMessage e ^ "\n"); Posix.Process.exit 0w1)
  fun command ["bench-extra", name, spec] = SOME (protect (one name spec))
    | command ["bench-oracle", name] = SOME (protect (oracle name))
    | command ["bench-negative", name] = SOME (protect (negative name))
    | command _ = NONE
end
