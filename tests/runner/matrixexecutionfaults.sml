(* Faults at the actual section-recovery, saved-image and producer boundaries.
   Fake compiler/VM programs are subjects; assertions and orchestration are SML. *)
structure MatrixExecutionFaults =
struct
  open Sh
  fun need (name, ok) = if ok then () else say ("FAIL matrix execution fault: " ^ name ^ "\n")
  fun script (file, body) =
    (write (file, "#!/bin/sh\n" ^ body ^ "\n"); Posix.FileSys.chmod (file,
       Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]))
  fun fixture () =
    let val c = MatrixModel.resolve {timing = false, directory = run ^ "/resolve"} "rune"
        val dir = run ^ "/recovery"
    in MatrixSuite.collect c dir "recovery_fault"; say (read (dir ^ "/recovery_fault.result")) end
  fun one () =
    let val dir = run ^ "/matrix-execution-faults"
        val () = mkdirs (dir ^ "/root/tests/basis")
        val () = mkdirs (dir ^ "/root/bin")
        val source = "val base__ = ()\n(*<< early *)\nval broken__ = MIGRATION_BAD\n(*>> early *)\n"
                     ^ "(*<< later *)\nval later__ = MIGRATION_LATER\n(*>> later *)\n"
        val () = write (dir ^ "/root/tests/basis/recovery_fault.sml", source)
        val () = List.app (fn name => write (dir ^ "/root/tests/basis/" ^ name ^ ".sml", "")) ["harness", "finish"]
        val compiler = dir ^ "/root/bin/compiler"
        val vm = dir ^ "/root/bin/vm"
        val () = script (compiler,
          "source=''; output=''; check=0\nwhile [ $# -gt 0 ]; do\ncase $1 in\n--typecheck-only) check=1; shift ;;\n-o) output=$2; shift 2 ;;\n*.sml) if grep -q MIGRATION_BAD \"$1\"; then printf '%s:3.1 Error: planted\\n' \"$1\" >&2; exit 1; fi\n"
           ^ "if grep -q MIGRATION_LATER \"$1\"; then source=$1; fi; shift ;;\n*) shift ;;\nesac\ndone\n"
           ^ "if [ $check -eq 0 ]; then if [ -n \"$source\" ]; then cat \"$source\" > \"$output\"; else printf EMPTY > \"$output\"; fi; fi")
        val () = script (vm, "if grep -q MIGRATION_LATER \"$1\"; then printf 'PASS later/survives\\nSUMMARY 1 checks, 0 failed\\n'; else printf 'SUMMARY 0 checks, 0 failed\\n'; fi")
        val environment = setEnv ("RUNE_TEST_ROOT", dir ^ "/root") o setEnv ("RUNE_TEST_RUN", dir ^ "/work")
                         o setEnv ("RUNE", compiler) o setEnv ("RUNEVM", vm)
        val () = mkdirs (dir ^ "/work")
        val status = Children.exec {addressSpace = SOME (1024 * 1024 * 1024), cpuTime = SOME 30,
                                    fileSize = SOME (1024 * 1024), core = SOME 0} environment
          {cmd = [fromRoot "bin/runevm", fromRoot "bin/rune-matrix.rbc", "matrix-recovery-fixture"], dir = SOME root,
           stdin = "", stdout = dir ^ "/recovery.out", stderr = dir ^ "/recovery.err", timeout = 30}
        val output = read (dir ^ "/recovery.out")
        val () = need ("early rejected section preserves later checks", status = 0 andalso
           String.isSubstring "FAIL @section/recovery_fault/early" output andalso String.isSubstring "PASS later/survives" output
           andalso not (String.isSubstring "FAIL @load" output))
        val cross : MatrixModel.config = {spec="xc2:smlnj-legacy",id="xc2:smlnj-legacy@fixture",
             library=MatrixModel.HostOnRune "smlnj-legacy",target=MatrixModel.Stack,
             compiler=MatrixModel.Rune compiler,command=compiler,vm=vm,extra="",version="fixture"}
        val checked=MatrixLoad.load (MatrixPrepare.context cross dir [] MatrixLoad.NoImage)
                       (dir ^ "/cross-typecheck") MatrixLoad.Check []
        val ()=need ("Rune typecheck on a host library needs no session SUMMARY",#loaded checked andalso #status checked=0)
        val () = need ("variant preserves line count", length (String.fields (fn c => c = #"\n") source)
                      = length (String.fields (fn c => c = #"\n") (MatrixSuite.variant source ["later"])))
        val () = need ("mismatched section rejected", ((MatrixSuite.sections "(*<< a *)\n(*>> b *)\n"; false) handle MatrixSuite.Failed _ => true))
        val () = need ("wrong summary", not (MatrixProgram.summary "PASS x\nSUMMARY 2 checks, 0 failed\n"))
        val () = need ("duplicate Basis label", List.exists (String.isPrefix "FAIL @load/")
                    (MatrixSuite.validated "fixture" "PASS x\nPASS x\nSUMMARY 2 checks, 0 failed\n"))
        val () = need ("failed check", not (MatrixProgram.summary "FAIL x\nSUMMARY 1 checks, 0 failed\n"))
        val () = need ("missing summary", not (MatrixProgram.summary "PASS x\n"))
        val () = need ("healthy standalone summary", MatrixProgram.summary "PASS x\nSUMMARY 1 checks, 0 failed\n")
        val c : MatrixModel.config = {spec = "xc1:polyml", id = "xc1:polyml@test", library = MatrixModel.RuneOnHost "polyml",
             target = MatrixModel.Native, compiler = MatrixModel.Host {name = "polyml", program = "/bin/false", library = ""},
             command = "/bin/false", vm = "", extra = "", version = "test"}
        val ctx = MatrixPrepare.context c dir [] (MatrixLoad.PolyImage (dir ^ "/missing.state"))
        val () = need ("missing image is explicit", ((MatrixLoad.load ctx (dir ^ "/image-work") MatrixLoad.Run []; false)
                                                    handle MatrixLoad.Failed _ => true))
        val () = MatrixPrepare.atomic (dir ^ "/basis.done", "failed: planted producer failure\n")
        val () = need ("failed producer wakes consumer", ((MatrixPrepare.ready c dir; false) handle MatrixPrepare.Failed _ => true))
        val failed = dir ^ "/failed-preparation"
        val () = need ("actual failed preparation publishes failure", ((MatrixPrepare.prepare c failed; false)
                                                   handle MatrixPrepare.Failed _ => true))
        val () = need ("failed preparation invalidates its key", not (exists (failed ^ "/basis.key"))
                         andalso String.isPrefix "failed:" (read (failed ^ "/basis.done")))
        val () = need ("consumer rejects failed preparation", ((MatrixPrepare.ready c failed; false)
                                                   handle MatrixPrepare.Failed _ => true))
        val () = write (dir ^ "/deviations.txt", "native:polyml@test | x | HOST-BUG | planted\n")
        val () = write (dir ^ "/probe.result", "PASS x\n")
        val native = MatrixModel.parseRow false "native:polyml@test\tnative\tpolyml\t/bin/false\t\t"
        val deviations = Expectations.read (dir ^ "/deviations.txt")
        val stale = MatrixSuite.stale deviations [native] ["probe"] (fn _ => dir) false
        val () = need ("stale expected failure", length stale = 1)
        val () = write (dir ^ "/probe.result", "FAIL x -- planted\n")
        val () = need ("explained failure consumes deviation", null (MatrixSuite.stale deviations [native] ["probe"] (fn _ => dir) false))
    in () end
end
