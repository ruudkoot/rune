(* Benchmark metadata and matrix-child fault contracts, independent of the
   production scripts' printed summaries. *)
structure BenchmarkFaults =
struct
  open Sh
  fun need (name, ok) = if ok then () else say ("FAIL benchmark fault: " ^ name ^ "\n")
  fun script (file, body) =
    (write (file, "#!/bin/sh\n" ^ body ^ "\n"); Posix.FileSys.chmod (file,
       Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]))
  fun catalogue () =
    let val dir = run ^ "/benchmark-catalogue-faults"
        val suite = dir ^ "/examples/benchmarks"
        val () = mkdirs (suite ^ "/shared")
        val () = mkdirs (suite ^ "/tak")
        val rows = String.fields (fn c => c = #"\n") (read (fromRoot "examples/benchmarks/manifest.tsv"))
        val selected = List.filter (fn row => case String.fields (fn c => c = #"\t") row of
                                     "tak" :: profile :: _ => profile <> "large" | _ => false) rows
        val original = hd rows ^ "\n" ^ String.concat (List.map (fn row => row ^ "\n") selected)
        val () = write (suite ^ "/manifest.tsv", original)
        val () = List.app (fn path => MatrixLoad.copy (fromRoot ("examples/benchmarks/" ^ path), suite ^ "/" ^ path))
              ["inventory.tsv", "shared/input.sml", "shared/tak.sml", "shared/main.sml", "tak/benchmark.sml",
               "tak/smoke.expected", "tak/normal.expected"]
        val valid = "benchmark\treason\ntak\trecursive pilot\n"
        val () = write (suite ^ "/routine.tsv", valid)
        fun check () =
          let val prior = OS.FileSys.getDir ()
              val () = OS.FileSys.chDir dir
              fun body () = let val rows = BenchCatalog.load "examples/benchmarks/manifest.tsv"
                           in BenchCatalog.validate rows; ignore (BenchCatalog.routine rows) end
          in (body () before OS.FileSys.chDir prior) handle e => (OS.FileSys.chDir prior; raise e) end
        val () = check ()
        fun rejects name = need (name, ((check (); false) handle Fail _ => true | IO.Io _ => true))
        val () = write (suite ^ "/routine.tsv", "benchmark\treason\nmissing\tunknown program\n")
        val () = rejects "unknown routine entry"
        val () = write (suite ^ "/routine.tsv", "benchmark\treason\ntak\tfirst\ntak\tduplicate\n")
        val () = rejects "duplicate routine entry"
        val () = write (suite ^ "/routine.tsv", "benchmark\treason\ntak\t\n")
        val () = rejects "missing routine reason"
        val () = write (suite ^ "/routine.tsv", valid)
        val () = write (suite ^ "/manifest.tsv", original ^ List.last selected ^ "\n")
        val () = rejects "duplicate benchmark profile"
        fun missing row = case String.fields (fn c => c = #"\t") row of name :: profile :: _ :: _ :: rest =>
                       String.concatWith "\t" (name :: profile :: "rune" :: "tak/missing.sml" :: rest)
                       | _ => raise Fail "invalid source fixture"
        val () = write (suite ^ "/manifest.tsv", hd rows ^ "\n" ^ String.concat (List.map (fn row => missing row ^ "\n") selected))
        val () = rejects "missing Rune program source"
        val () = write (suite ^ "/manifest.tsv", original)
        val () = OS.FileSys.remove (suite ^ "/tak/normal.expected")
        val () = rejects "missing expected result fixture"
    in () end
  fun matrixStatus () =
    let val dir = run ^ "/benchmark-matrix-status"
        val () = mkdirs dir
        fun one (host, mode) =
          let val job = dir ^ "/" ^ host ^ "-" ^ mode
              val () = mkdirs job
              val compiler = job ^ "/compiler"
              val () = script (compiler, if mode = "timeout" then "exec sleep 5" else "printf 'planted compiler error\\n' >&2; exit 7")
              val c : MatrixModel.config = {spec = "native:" ^ host, id = "native:" ^ host ^ "@999.0",
                library = MatrixModel.NativeBasis host, target = MatrixModel.Native,
                compiler = MatrixModel.Host {name = host, program = compiler, library = job},
                command = compiler, vm = job, extra = "", version = "999.0"}
              val ctx : MatrixLoad.context = {config = c, directory = job, prefix = [], image = MatrixLoad.NoImage,
                  standalone = true, input = "", data = [], timeout = 1, memoryKiB = 1048576}
              val result = MatrixLoad.load ctx (job ^ "/program") MatrixLoad.Run [fromRoot "examples/benchmarks/shared/input.sml"]
              val expected = if mode = "timeout" then 124 else 7
          in need (host ^ " " ^ mode ^ " status", not (#loaded result) andalso #status result = expected);
             need (host ^ " " ^ mode ^ " never executed", #output result = "" andalso not (exists (job ^ "/program/prog")));
             need (host ^ " " ^ mode ^ " diagnostic", String.isSubstring
                         (if mode = "timeout" then "timed out after 1 s" else "planted compiler error") (#messages result)) end
    in List.app one [("mlton", "error"), ("mlton", "timeout"), ("mlkit", "error"), ("mlkit", "timeout")] end
  fun execute dir name working envf command =
    let val output = dir ^ "/" ^ name ^ ".out"
        val errors = dir ^ "/" ^ name ^ ".err"
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 300,
                                    fileSize = SOME (64 * 1024 * 1024), core = SOME 0} envf
          {cmd = command, dir = SOME working, stdin = "", stdout = output, stderr = errors, timeout = 300}
    in (status, read output, read errors) end
  fun provenance () =
    let val dir = run ^ "/benchmark-provenance-faults"
        val foreign = dir ^ "/compiler"
        val () = mkdirs (foreign ^ "/bin")
        val () = mkdirs (foreign ^ "/lib/basis")
        val () = mkdirs (dir ^ "/record")
        val () = mkdirs (dir ^ "/custom-record")
        val () = List.app (fn (name, text) => write (foreign ^ "/bin/" ^ name, text))
           [("rune", "fixture compiler\n"), ("rune.rbc", "fixture payload\n"),
            ("rune.stack.rbc", "fixture stack payload\n"), ("rune.new.rbc", "fixture legacy register payload\n")]
        val () = write (foreign ^ "/lib/basis/MANIFEST", "# fixture basis\n")
        val () = write (foreign ^ "/lib/basis/fixture.sml", "val basisFixture = 1\n")
        fun git label args =
          let val (status, output, errors) = execute dir label foreign (fn e => e)
              (["git", "-c", "core.hooksPath=/dev/null"] @ args)
          in if status = 0 then output else raise Fail ("fixture git " ^ label ^ ": " ^ errors) end
        val () = ignore (git "init" ["init", "--quiet"])
        val () = ignore (git "add" ["add", "bin", "lib"])
        val () = ignore (git "commit" ["-c", "user.name=Benchmark Fixture", "-c", "user.email=fixture@example.invalid",
                         "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Create compiler identity fixture"])
        val revision = Hosts.trim (git "revision" ["rev-parse", "HEAD"])
        val () = write (foreign ^ "/lib/basis/fixture.sml", "val basisFixture = 2\n")
        fun record tool destination label =
          let val (status, _, errors) = execute dir label root (fn e => e)
                ["/bin/sh", "-c", ". \"$1\"; shift; bench_tool_repository \"$@\"", "benchmark-provenance",
                  fromRoot "scripts/benchmark-provenance.sh", "compiler", tool, destination]
          in if status = 0 then () else raise Fail ("provenance producer failed: " ^ errors) end
        val () = record (foreign ^ "/bin/rune") (dir ^ "/record") "foreign"
        val identity = lines (read (dir ^ "/record/compiler-repository.tsv"))
        fun contains line = List.exists (fn actual => actual = line) identity
        val () = need ("foreign compiler repository", contains ("repository\t" ^ foreign))
        val () = need ("foreign compiler revision", contains ("revision\t" ^ revision))
        val () = need ("foreign compiler dirty state", contains "dirty\t1")
        val payloads = read (dir ^ "/record/compiler-payloads.sha256")
        val () = List.app (fn name => need ("actual compiler payload " ^ name,
                       String.isSubstring (foreign ^ "/bin/" ^ name) payloads)) ["rune.rbc", "rune.stack.rbc", "rune.new.rbc"]
        val (status, hashes, _) = execute dir "basis" foreign (fn e => e)
                    ["sha256sum", "lib/basis/MANIFEST", "lib/basis/fixture.sml"]
        val () = need ("actual compiler basis hashes", status = 0 andalso hashes = read (dir ^ "/record/basis.sha256"))
        (* A launcher outside every Git repository must remain unidentified. *)
        val stem = "/tmp/rune-benchmark-provenance-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        fun reserve i =
          let val path = stem ^ "-" ^ Int.toString i
              val fd = Posix.FileSys.createf (path, Posix.FileSys.O_WRONLY, Posix.FileSys.O.flags [Posix.FileSys.O.excl],
                              Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
          in Posix.IO.close fd; path end
          handle e as OS.SysErr (_, SOME code) => if code = Posix.Error.exist andalso i < 100 then reserve (i + 1) else raise e
        val custom = reserve 0
        val () = write (custom, "custom launcher\n")
        val () = record custom (dir ^ "/custom-record") "custom"
        val () = OS.FileSys.remove custom
        val () = need ("unknown launcher repository", List.exists (fn line => line = "repository\tunavailable")
                        (lines (read (dir ^ "/custom-record/compiler-repository.tsv"))))
        val () = need ("unknown launcher payloads", read (dir ^ "/custom-record/compiler-payloads.sha256") = "")
        val () = need ("unknown launcher basis", not (exists (dir ^ "/custom-record/basis.sha256")))
    in () end
end
