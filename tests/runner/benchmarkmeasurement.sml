(* Measurement correctness assertions. The production measurement/provenance
   tools remain explicit producers until P2.14; they make no test verdicts. *)
structure BenchmarkMeasurement =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun invoke dir name envf args = BenchmarkFaults.execute dir name root envf args
  fun produced log =
    case List.filter (String.isPrefix "BENCH MEASUREMENT ") (lines log) of
      [line] => String.extract (line, size "BENCH MEASUREMENT ", NONE)
    | _ => raise Failed "measurement producer did not identify exactly one run"
  fun status () =
    let val dir = run ^ "/measurement-status"
        val () = mkdirs dir
        val compiler = dir ^ "/sml"
        val () = BenchmarkFaults.script (compiler,
          "if [ \"$1\" = @SMLversion ]; then printf 'sml 999.0\\n'; exit 0; fi\n"
          ^ "case $MEASUREMENT_FAULT in error) printf 'planted compiler error\\n' >&2; exit 7 ;;\n"
          ^ "timeout) printf 'planted deadline status\\n' >&2; exit 124 ;; no_image) exit 0 ;; esac\nexit 8")
        fun one (mode, expected, raw) =
          let val (status, output, errors) = invoke dir mode (setEnv ("MEASUREMENT_FAULT", mode) o setEnv ("SMLNJ", compiler))
                 ["sh", fromRoot "scripts/measure-benchmarks.sh", "time", "--profile", "smoke", "--filter", "=tak",
                  "--configs", "native:smlnj-legacy", "--samples", "1"]
              val record = produced output
              val phase = record ^ "/tak/native-smlnj-legacy/build/compile"
              val () = need (status <> 0, "measurement accepted failed compiler " ^ mode)
              val () = need (Hosts.trim (read (phase ^ "/exit")) = Int.toString raw, "measurement erased compiler status " ^ mode)
              val rows = lines (read (record ^ "/samples.tsv"))
              val () = need (length rows = 2, "failed compile must produce exactly one phase record")
              val fields = String.fields (fn c => c = #"\t") (List.nth (rows, 1))
              val () = need (length fields >= 8 andalso List.nth (fields, 4) = "compile" andalso List.nth (fields, 7) = expected,
                             "measurement compile category differs for " ^ mode)
          in if mode = "no_image" then need (String.isSubstring "without an exported SML/NJ image" (read (phase ^ "/stderr")),
                                               "missing export was not diagnosed") else () end
    in List.app one [("error", "compile-error", 7), ("timeout", "timeout", 124), ("no_image", "compile-error", 0)] end
  fun classify dir exit rounds =
    let val () = need (exists (dir ^ "/stdout") andalso exists (dir ^ "/stderr"), "classification input is missing")
        val (status, output, errors) = invoke dir "classification" (fn e => e)
          ["/bin/sh", "-c", ". \"$1\"; phase_dir=$2; phase_exit=$3; rounds=$4; status=0; validate; printf '%s\\t%s\\n' \"$category\" \"$status\"",
           "benchmark-result", fromRoot "scripts/benchmark-result.sh", dir, Int.toString exit, Int.toString rounds]
    in need (status = 0, "result classification producer failed: " ^ errors);
       case String.fields (fn c => c = #"\t") (Hosts.trim output) of [category, state] => (category, state)
        | _ => raise Failed "malformed result classification record" end
  fun measuredFailures () =
    let val dir = run ^ "/measurement-failures"
        val () = mkdirs dir
        val launch = dir ^ "/launch.sml"
        val () = write (launch, "val _ = OS.Process.exit (BenchMeasure.main ())\n")
        fun compile dir stack sources =
          let val rbc = dir ^ "/prog.rbc"
              val () = rmTree rbc
              val (status, _, errors) = invoke dir "compile" (fn e => e)
                    ([fromRoot "bin/rune", "--lint"] @ (if stack then ["--target=stack"] else [])
                     @ List.map fromRoot sources @ [launch, "-o", rbc])
          in need (status = 0 andalso exists rbc andalso OS.FileSys.fileSize rbc > 0, "measurement fixture did not compile: " ^ errors); rbc end
        fun execute dir vm rbc text =
          let val input = dir ^ "/input"
              val () = write (input, text)
              val status = Children.exec {addressSpace = SOME (1024 * 1024 * 1024), cpuTime = SOME 120,
                                          fileSize = SOME (64 * 1024 * 1024), core = SOME 0} (fn e => e)
                   {cmd = [fromRoot vm, rbc], dir = SOME root, stdin = input, stdout = dir ^ "/stdout", stderr = dir ^ "/stderr", timeout = 120}
              val output = read (dir ^ "/stdout")
          in need (status <> 0 andalso List.exists (String.isPrefix "FAIL ") (lines output)
                            andalso not (List.exists (String.isPrefix "SAMPLE ") (lines output)),
                         "incorrect result produced successful timing samples"); status end
        val wrong = dir ^ "/wrong-result"
        val () = mkdirs wrong
        val rbc = compile wrong true ["examples/benchmarks/shared/input.sml", "examples/benchmarks/shared/tak.sml",
                      "examples/benchmarks/tak/benchmark.sml", "examples/benchmarks/shared/measure.sml"]
        val () = ignore (execute wrong "bin/runevm-stack" rbc "tak\n18 12 6 1\n999\n3\n")
        fun exceptionCase (name, expression, expected) =
          let val dir = dir ^ "/" ^ name
              val () = mkdirs dir
              val source = dir ^ "/benchmark.sml"
              val () = write (source, "structure Benchmark = struct val name=\"negative\" fun run (_:string list):string = " ^ expression ^ " end\n")
              val rbc = compile dir false ["examples/benchmarks/shared/input.sml", source, "examples/benchmarks/shared/measure.sml"]
              val status = execute dir "bin/runevm" rbc "negative\nunused\nunused\n1\n"
          in need (classify dir status 1 = (expected, "1"), "incorrect exception category: " ^ name) end
        val () = List.app exceptionCase [("numeric", "raise Fail \"incorrect result: perturbed numerical value\"", "incorrect-result"),
                                         ("runtime", "raise Div", "runtime-failure")]
        fun format (name, message, expected) =
          let val dir = dir ^ "/format-" ^ name
              val () = mkdirs dir
              val () = write (dir ^ "/stdout", message ^ "\n")
              val () = write (dir ^ "/stderr", "")
          in need (classify dir 1 1 = (expected, "1"), "incorrect native exception format: " ^ name) end
    in List.app format [("bare", "FAIL negative -- incorrect result: numeric fixture", "incorrect-result"),
           ("colon", "FAIL negative -- Fail: incorrect result: numeric fixture", "incorrect-result"),
           ("quoted", "FAIL negative -- Fail \"incorrect result\"", "incorrect-result"),
           ("quoted-runtime", "FAIL negative -- Fail \"ordinary runtime failure\"", "runtime-failure")] end
  fun integration () =
    let val dir = run ^ "/measurement-integration"
        val () = mkdirs dir
        val (status, output, errors) = invoke dir "instrumented" (setEnv ("RUNEVM_OPTIONS", "--count"))
                         ["sh", "scripts/measure-benchmarks.sh", "time", "--filter", "tak"]
        val () = need (status <> 0 andalso String.isSubstring "instrumented VM options" (output ^ errors),
                       "instrumented run was accepted as headline timing")
        val shared = dir ^ "/shared-run"
        val () = mkdirs shared
        val () = write (shared ^ "/keep", "keep this matrix worker\n")
        val (status, output, errors) = invoke dir "isolated" (setEnv ("RUNE_MATRIX_RUN", shared))
             ["sh", "scripts/measure-benchmarks.sh", "count", "--profile", "smoke",
              "--filter", "primes-strict", "--configs", "rune"]
        val () = need (status = 0, "isolated measurement failed: " ^ errors)
        val () = need (read (shared ^ "/keep") = "keep this matrix worker\n", "measurement removed another matrix worker")
        val record = produced output
        val resolved = lines (read (record ^ "/primes-strict/rune/config.tsv"))
    in need (length resolved = 1, "measurement configuration resolution collided") end
end
