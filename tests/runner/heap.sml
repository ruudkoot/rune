(* Scheduling for the remaining census, simulator, layout and gcbench
   checks. Trace producers are ordinary dependency nodes in this tree. *)
structure Heap =
struct
  open Sh
  fun tagged tags tree = List.foldl (fn (tag, tree) => Test.tag tag tree) tree tags
  fun jobIn pools (name, args, after, memory) =
    Test.it name {program = "/bin/sh",
      args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-heap-check " ^ String.concatWith " " (List.map quote args)],
      env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 1800, cap = 0,
      cpus = 1, memory = memory, pools = pools, exclusive = false, after = after, judge = failLines} : Run.command Test.tree
  fun job args = jobIn [] args
  fun prepare which () =
    let val dir = HeapChecks.directory ("prepare-" ^ which)
        val target = if which = "layouts" then ["-C", "tests/layouts", "CC=" ^ env ("CC", "cc")]
                     else ["gcbench", "CC=" ^ env ("CC", "cc")]
    in ignore (HeapChecks.commandIn (unsetEnv ["MAKEFLAGS", "MFLAGS", "MAKELEVEL"]) root dir "make"
                (["make", "--no-print-directory", "JOBS=1"] @ target)) end
  fun public label f () = f () handle HeapChecks.Failed message =>
        (TextIO.output (TextIO.stdErr, "FAIL " ^ label ^ ": " ^ message ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w1)
    | TraceCheck.Invalid message =>
        (TextIO.output (TextIO.stdErr, "FAIL " ^ label ^ ": " ^ message ^ "\n"); TextIO.flushOut TextIO.stdErr; Posix.Process.exit 0w1)
  fun command ["heap-census"] = SOME (HeapChecks.protect "census" HeapChecks.census)
    | command ["heap-trace-check", dir] = SOME (public "trace" (fn () => TraceCheck.check dir))
    | command ["heap-faults"] = SOME (HeapChecks.protect "trace faults" HeapFaults.one)
    | command ["heap-boundary-faults"] = SOME (HeapChecks.protect "boundary faults" HeapFaults.boundaries)
    | command ["heap-prepare", which] = SOME (HeapChecks.protect "prepare" (prepare which))
    | command ["heap-synthetic", seed, sample] = SOME (HeapChecks.protect "synthetic" (fn () => HeapChecks.synthetic (seed, sample)))
    | command ["heap-coverage", ci, li, band] = SOME (HeapChecks.protect "coverage" (fn () =>
          HeapChecks.coverage (valOf (Int.fromString ci), valOf (Int.fromString li), band)))
    | command ["heap-layout", kernel, n, small] = SOME (HeapChecks.protect "layout" (fn () => HeapChecks.layout (kernel, n, small)))
    | command ["heap-gcsim", which] = SOME (HeapChecks.protect "gcsim" (fn () => HeapChecks.gcsim which))
    | command ["heap-gc-trace"] = SOME (HeapChecks.protect "gcbench trace" HeapChecks.gcTrace)
    | command ["heap-gc-ops"] = SOME (HeapChecks.protect "gcbench ops" HeapChecks.gcOps)
    | command ["heap-gcbench", name] = SOME (HeapChecks.protect "gcbench" (fn () => HeapChecks.gcbench name))
    | command ["heap-produce", name] = SOME (HeapChecks.protect "trace producer" (fn () => CensusTrace.produce (name, "8192")))
    | command ["heap-replay", name] = SOME (HeapChecks.protect "trace replay" (fn () => CensusTrace.replay name))
    | command ("heap-validate" :: "--out" :: out :: names) = SOME (public "trace replay" (fn () => CensusTrace.validate out names))
    | command ("heap-validate" :: names) = SOME (public "trace replay" (fn () => CensusTrace.validate "tests/out/heapsim" names))
    | command ["heap-jitdump"] = SOME (HeapChecks.protect "JIT dump" JitDumpCheck.produce)
    | command ["heap-jitdump-analysis"] = SOME (HeapChecks.protect "JIT analysis" JitDumpCheck.analysis)
    | command ["heap-jitdump-faults"] = SOME (HeapChecks.protect "JIT dump faults" JitDumpCheck.faults)
    | command _ = NONE
  val capabilities = [{name = "objdump", probe = "command -v objdump", hint = "install binutils for the JIT disassembly check"},
                      {name = "jit", probe = "bin/runevm --jit-check", hint = "build a VM with JIT support for JIT dump checks"}]
  val covers = ["covers:runtime/census/*", "covers:tools/heapsim/*", "covers:tests/runner/heap*.sml", "covers:tests/runner/tracecheck.sml",
                "covers:tests/runner/censustrace.sml", "covers:tests/runner/jitdumpcheck.sml"]
  val seeds = ["1", "2", "3"]
  val samples = ["65536", "4096", "512"]
  val gcsim = ["alt32", "alt128", "line1", "minors", "satb", "identity/lo", "identity/hi"]
       @ List.concat (List.map (fn band => List.map (fn allocator => "nursery/" ^ band ^ "/" ^ allocator)
                                  ["copy", "immix", "segfit", "bestfit", "chez"]) ["lo", "hi"])
  val tree = Test.describe "heap"
    [tagged ("check" :: "test-census" :: covers) (job ("census", ["heap-census"], [], 500)),
     tagged ("check" :: "quick" :: covers) (job ("trace-faults", ["heap-faults"], [], 100)),
     tagged ("check" :: "quick" :: covers) (job ("boundary-faults", ["heap-boundary-faults"], [], 200)),
     tagged ("check" :: "check-heapsim" :: covers)
       (Test.describe "synthetic" (List.concat (List.map (fn seed => List.map (fn sample =>
          job (HeapChecks.traceName (seed, sample), ["heap-synthetic", seed, sample], [], 300)) samples) seeds))),
     tagged ("check" :: "check-heapsim" :: covers)
       (Test.describe "coverage" (List.concat (List.tabulate (length HeapChecks.collectors, fn ci =>
         List.concat (List.tabulate (length HeapChecks.layouts, fn li => List.map (fn band =>
           job (Int.toString ci ^ "/" ^ Int.toString li ^ "/" ^ band,
                ["heap-coverage", Int.toString ci, Int.toString li, band], ["heap/synthetic/s1-4096"], 300)) ["lo", "hi"])))))),
     tagged ("check" :: "check-heapsim" :: covers)
       (Test.describe "replay" (List.map (fn name => Test.describe name
         [job ("produce", ["heap-produce", name], [], 1500),
          job ("validate", ["heap-replay", name], ["heap/replay/" ^ name ^ "/produce"], 1000)]) ["compile-sigs", "intinf_fact"])),
     tagged ("check" :: "check-gcsim" :: covers) (Test.describe "gcsim" (List.map (fn name => job (name, ["heap-gcsim", name], [], 1000)) gcsim)),
     tagged ["check", "check-layouts", "layout", "covers:tests/layouts/*"]
       (Test.describe "layouts" (jobIn ["build"] ("prepare", ["heap-prepare", "layouts"], [], 500)
         :: List.map (fn (name, n, small) => job (name, ["heap-layout", name, n, small], ["heap/layouts/prepare"], 500)) HeapChecks.kernels)),
     Test.requires ["native-host"] (tagged ["check", "check-gcbench", "covers:tests/gcbench/*"]
       (Test.describe "gcbench"
         ([jobIn ["build"] ("prepare", ["heap-prepare", "gcbench"], [], 500),
           job ("trace", ["heap-gc-trace"], ["heap/gcbench/prepare"], 500),
           job ("ops", ["heap-gc-ops"], [], 100)]
          @ List.map (fn (name, _) => job (name, ["heap-gcbench", name],
            ["heap/gcbench/prepare"] @ (if name = "h5-ops" then ["heap/gcbench/ops"]
                  else if List.exists (fn n => n = name) ["h1", "h5", "h5-immix"] then ["heap/gcbench/trace"] else []), 500)) HeapChecks.gcCases))),
     Test.requires ["jit"] (tagged ["check", "test-register-jit", "covers:runtime/register/jit/*", "covers:tests/register/*", "covers:scripts/jit-dump.py"]
       (Test.describe "jitdump" [job ("binary", ["heap-jitdump"], [], 300),
          Test.requires ["python3", "objdump"] (job ("analysis", ["heap-jitdump-analysis"], ["heap/jitdump/binary"], 300)),
          job ("faults", ["heap-jitdump-faults"], [], 300)]))]
end
