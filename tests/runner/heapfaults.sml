(* Hand-built traces exercise the independent reader at binary boundaries;
   mutations never touch a runtime-produced trace or a checked-in golden. *)
structure HeapFaults =
struct
  open Sh
  fun bytes ns = String.implode (List.map Char.chr ns)
  fun u32 n = BytecodeFixture.le 4 n
  fun u64 n = BytecodeFixture.le 8 n
  fun zeros n = String.implode (List.tabulate (n, fn _ => #"\000"))
  val meta = "format 2\nlayout W8\nfields 1\ngraph 1\nobjects 1\nbytes 16\ncount_bytes 16\ncount_objects 1\nsamples 1\nstores 1\n"
  val sample = u64 16 ^ u64 16 ^ u64 1 ^ u64 0 ^ u64 1 ^ u32 1 ^ u32 0 ^ u32 0 ^ u32 0 ^ u32 0 ^ u32 2
  val allocation = zeros 16 ^ bytes [1, 0, 0, 0] ^ u32 1 ^ u32 0 ^ u32 0
  val store = u32 2 ^ u32 1 ^ u32 0 ^ u32 0 ^ u32 0 ^ bytes [0, 0, 0, 1]
  val files = [("meta.txt", meta), ("alloc.bin", allocation), ("death.bin", u32 0 ^ u32 4294967295),
               ("samples.bin", sample), ("stores.bin", store), ("fields.bin", zeros 2), ("graph.bin", u32 0)]
  fun replace (text, offset, value) = String.substring (text, 0, offset) ^ value ^ String.extract (text, offset + size value, NONE)
  fun one () =
    let
      val base = HeapChecks.directory "faults"
      fun fixture name changes =
        let val dir = base ^ "/" ^ name
            val () = mkdirs dir
            fun value (name, original) = (name, case List.find (fn (n, _) => name = n) changes of SOME (_, s) => s | NONE => original)
            val () = List.app (fn (name, s) => write (dir ^ "/" ^ name, s)) (List.map value files)
        in dir end
      fun bad name changes =
        let val dir = fixture name changes
            val refused = ((TraceCheck.check dir; false) handle TraceCheck.Invalid _ => true)
        in HeapChecks.need (refused, "trace reader accepted " ^ name) end
      val () = TraceCheck.check (fixture "valid" [])
      val () = List.app (fn (name, s) => bad ("truncated-" ^ name) [(name, String.substring (s, 0, size s - 1))])
                      (List.filter (fn (name, _) => name <> "meta.txt") files)
      val emptyMeta = String.concat (List.map (fn line => (if line = "stores 1" then "stores 0" else line) ^ "\n") (lines meta))
      val missing = fixture "missing-store" [("meta.txt", emptyMeta), ("stores.bin", "")]
      val () = TraceCheck.check missing
      val () = OS.FileSys.remove (missing ^ "/stores.bin")
      val () = HeapChecks.need (((TraceCheck.check missing; false) handle TraceCheck.Invalid _ => true), "missing store file was accepted")
      val () = bad "bad-kind" [("alloc.bin", replace (allocation, 16, bytes [9]))]
      val () = bad "last-id" [("samples.bin", replace (sample, 32, u64 2))]
      val () = bad "clock" [("samples.bin", replace (sample, 0, u64 17))]
      val () = bad "live-bytes" [("samples.bin", replace (sample, 8, u64 15))]
      val () = bad "live-objects" [("samples.bin", replace (sample, 16, u64 0))]
      val () = bad "frame-bounds" [("samples.bin", replace (sample, 52, u32 2))]
      val () = bad "missing-final-flag" [("samples.bin", replace (sample, 60, u32 0))]
      val () = bad "death-past-end" [("death.bin", u32 0 ^ u32 2)]
      val () = bad "field-spare-bit" [("fields.bin", bytes [64, 0])]
      val () = bad "field-class" [("fields.bin", bytes [3, 0])]
      val () = bad "graph-class" [("graph.bin", u32 1)]
      val () = bad "graph-self" [("graph.bin", u32 1), ("fields.bin", bytes [5, 0])]
      val () = bad "store-clock" [("stores.bin", replace (store, 0, u32 1))]
      val () = bad "store-source" [("stores.bin", replace (store, 4, u32 2))]
      val () = bad "store-new" [("stores.bin", replace (store, 8, u32 2))]
      val () = bad "store-kind" [("stores.bin", replace (store, 23, bytes [2]))]
      val () = bad "store-flags" [("stores.bin", replace (store, 21, bytes [2]))]
      val () = bad "store-field" [("stores.bin", replace (store, 16, u32 1))]
      val wrongTotal = String.concat (List.map (fn line => (if line = "bytes 16" then "bytes 17" else line) ^ "\n") (lines meta))
      val () = bad "wrong-byte-total" [("meta.txt", wrongTotal)]
      val () = HeapChecks.need (TraceCheck.uint (bytes [255, 255, 255, 255], 0, 4) = 4294967295
                  andalso TraceCheck.uint (bytes [255, 255, 255, 255, 255, 255, 255, 255], 0, 8) = 18446744073709551615,
                  "unsigned binary fields lost their high bit")
      val () = HeapChecks.need (List.all (fn x => CensusTrace.copiedWithin (100, 120, x)) [90, 130]
                  andalso List.all (fn x => not (CensusTrace.copiedWithin (120, 100, x))) [89, 131]
                  andalso CensusTrace.copiedWithin (100, 101, 100) andalso not (CensusTrace.copiedWithin (100, 101, 99)),
                  "copied-byte tolerance changed at its inclusive or rounded boundary")
      val () = HeapChecks.need (CensusTrace.liveWithin (100000, 120000, 34464)
                  andalso CensusTrace.liveWithin (120000, 100000, 185536)
                  andalso not (CensusTrace.liveWithin (100000, 120000, 34463))
                  andalso not (CensusTrace.liveWithin (100000, 120000, 185537)),
                  "live-byte tolerance changed at its inclusive boundary")
    in () end
  fun boundaries () =
    let
      val dir = HeapChecks.directory "boundary-faults"
      fun script (path, text) =
        (write (path, "#!/bin/sh\n" ^ text ^ "\n");
         Posix.FileSys.chmod (path, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]))
      val compiler = dir ^ "/failing-compiler"
      val () = script (compiler, "echo 'planted compiler failure' >&2; exit 7")
      val runDir = dir ^ "/producer"
      val recipe = runDir ^ "/heap-checks/replay-list_ops/recipe.tsv"
      val () = mkdirs (OS.Path.dir recipe)
      val () = write (recipe, "stale recipe\n")
      val marker = dir ^ "/consumer-started"
      val () = rmTree marker
      val helper = fromRoot "bin/rune-heap-check"
      fun command (name, args, envf, deps) =
        {program = hd args, args = args, env = envf (Posix.ProcEnv.environ ()), dir = root,
         stdin = "/dev/null", stdout = dir ^ "/" ^ name ^ ".out", stderr = dir ^ "/" ^ name ^ ".err",
         timeout = Time.fromSeconds 30, cap = 1000000, cost = 0.0, cpus = 1, memory = 100,
         pools = [], exclusive = false, failedLast = false, deps = deps} : Supervisor.command
      val producer = command ("producer", [helper, "heap-produce", "list_ops"],
          setEnv ("RUNE_NEW", compiler) o setEnv ("RUNE_TEST_RUN", runDir), [])
      val consumer = command ("consumer", ["/bin/sh", "-c", "touch " ^ quote marker], fn e => e, [0])
      val outcomes = Array.array (2, NONE : Supervisor.outcome option)
      val () = Supervisor.run {commands = Vector.fromList [producer, consumer], cpus = 2, memory = 200,
        finished = fn (i, result) =>
          (Array.update (outcomes, i, SOME (#outcome result));
           if i = 0 then
             (HeapChecks.need (isSome (failLines (result, {stdout = dir ^ "/producer.out", stderr = dir ^ "/producer.err"})),
                               "failed producer was judged successful"); Supervisor.NotPassed)
           else Supervisor.Passed), tick = fn _ => ()}
      val () = HeapChecks.need (Array.sub (outcomes, 1) = SOME Supervisor.Cancelled andalso not (exists marker)
                 andalso not (exists recipe), "failed producer published a recipe or started its consumer")
      val fixture = dir ^ "/fixture"
      val binaries = fixture ^ "/tests/out/layouts/faultcc"
      val () = mkdirs binaries
      val () = script (binaries ^ "/harness-a", "printf 'checksum kernel 1\\n'")
      val () = script (binaries ^ "/harness-b", "printf 'checksum kernel 2\\n'")
      val () = mkdirs (fixture ^ "/tests/layouts")
      val () = mkdirs (fixture ^ "/tests/gcbench")
      val () = mkdirs (fixture ^ "/tests/out/gcbench")
      val () = script (fixture ^ "/tests/out/gcbench/gcbench", "echo 'FAILED planted self-check' >&2; exit 1")
      fun checker (name, args, message) =
        let
          val status = Children.exec HeapChecks.limits
            (setEnv ("RUNE_TEST_ROOT", fixture) o setEnv ("RUNE_TEST_RUN", dir ^ "/" ^ name) o setEnv ("CC", "faultcc"))
            {cmd = helper :: args, dir = SOME fixture, stdin = "", stdout = dir ^ "/" ^ name ^ ".out",
             stderr = dir ^ "/" ^ name ^ ".err", timeout = 30}
        in HeapChecks.need (status = 0 andalso String.isSubstring message (read (dir ^ "/" ^ name ^ ".out")),
                             "checker accepted " ^ name) end
      val () = checker ("wrong-layout-checksum", ["heap-layout", "kernel", "1", "1"], "differs from")
      val () = checker ("failed-gc-self-check", ["heap-gcbench", "h2"], "FAILED planted self-check")
    in () end
end
