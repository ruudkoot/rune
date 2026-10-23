(* Planted faults for the native-host adapter: a PASS before a crash or
   timeout must not pass, and a session can exit 0 after a static error.
   These use fake compiler executables, so make check needs no extra host. *)
structure HostChecks =
struct
  open Sh
  fun one () =
    let
      val dir = run ^ "/host-checks"
      val () = mkdirs dir
      fun check (name, ok) = if ok then () else say ("FAIL host-adapter: " ^ name ^ "\n")
      fun script (name, text) =
        let val file = dir ^ "/" ^ name
            val () = write (file, "#!/bin/sh\n" ^ text ^ "\n")
            val () = Posix.FileSys.chmod (file, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr])
        in file end
      fun build (host, text, timeout) =
        Hosts.build {host = {name = host, program = script ("compiler with spaces", text), library = "library with spaces"},
                     name = "program", sources = ["source with spaces.sml"], dir = dir ^ "/build with spaces",
                     runDir = root, timeout = timeout, memory = 256}
      val pass = build ("smlnj-legacy", "test -r tests/lib/unicode/GraphemeBreakTest.txt || exit 10\n"
                        ^ "printf 'Standard ML fake\n[opening x]\nPASS suite\nval x = 1\n'", 5)
      val () = check ("SML/NJ session output", #built pass andalso #status pass = 0
                     andalso Hosts.libraryOutput "smlnj-legacy" (#output pass) = "PASS suite\n")
      val poly = build ("polyml", "printf '%s\\n' \"$@\" > " ^ quote (dir ^ "/poly.args")
                        ^ "\nprintf 'val x = 1\nPASS suite\n> '\n", 5)
      val () = check ("Poly/ML session output", #built poly andalso #status poly = 0
                     andalso Hosts.libraryOutput "polyml" (#output poly) = "PASS suite\n")
      val () = check ("Poly/ML quoted source path", String.isSubstring "source with spaces.sml\";" (read (dir ^ "/build with spaces/program.use")))
      val () = check ("Poly/ML heap budget", lines (read (dir ^ "/poly.args")) = ["-q", "--maxheap", "256"])
      val err = build ("smlnj32", "printf 'input.sml:1.1 Error: planted\nPASS suite\n'", 5)
      val () = check ("static error with status 0", not (#built err) andalso #status err = 0)
      val err = build ("polyml", "printf 'input.sml:1: error: planted\nPASS suite\n'", 5)
      val () = check ("Poly/ML static error with status 0", not (#built err))
      val nonzero = build ("smlnj-dev", "printf 'PASS suite\n'; exit 7", 5)
      val () = check ("PASS before a failing exit", #status nonzero = 7)
      val crash = build ("smlnj-legacy", "printf 'PASS suite\n'; kill -SEGV $$", 5)
      val () = check ("PASS before a crash", #status crash = 139)
      val timeout = build ("smlnj-dev", "printf 'PASS suite\n'; exec sleep 30", 1)
      val () = check ("PASS before a timeout", #status timeout = 124)
      val leak = build ("smlnj-dev", "sleep 30 &\nprintf 'PASS suite\n'", 5)
      val () = check ("PASS before a leaked process", #status leak = 125)
      val floodFile = dir ^ "/flood"
      val flood = execLimited {addressSpace = SOME (64 * 1024 * 1024), cpuTime = NONE, fileSize = SOME 4096, core = SOME 0}
        (fn e => e) {cmd = [script ("flood", "exec yes FLOOD")], dir = NONE, stdin = "", stdout = floodFile ^ ".out",
                     stderr = floodFile ^ ".err", timeout = 5}
      val () = check ("output flood capped", flood <> 0 andalso OS.FileSys.fileSize (floodFile ^ ".out") = 4096)
      fun rejects (r : Hosts.result) = not (LibHosts.accepts "props" {built = #built r, status = #status r, output = #output r} "" "")
      val () = check ("bad process outcome cannot pass the suite", List.all rejects [err, nonzero, crash, timeout, leak])
      val compiled =
        "test \"$SML_LIB\" = 'library with spaces' || exit 9\n"
        ^ "cat > \"$2\" <<'PROGRAM'\n#!/bin/sh\n"
        ^ "test -z \"${FORCE_COLOR-}${CLICOLOR_FORCE-}\" || exit 8\nprintf 'PASS suite\\n'\nPROGRAM\nchmod +x \"$2\""
      val native = build ("mlkit", compiled, 5)
      val () = check ("MLKit build and executable", #built native andalso #status native = 0 andalso #output native = "PASS suite\n")
      val rejected = build ("mlton", "exit 3", 5)
      val () = check ("compiler exit checked", not (#built rejected) andalso #status rejected = 3)
      val () = check ("PASS required", not (LibHosts.outputOK "props" "" "" ""))
      val () = check ("FAIL after PASS", not (LibHosts.outputOK "props" "PASS a\nFAIL b\n" "" ""))
      val () = check ("KAT oracle", LibHosts.outputOK "kat" "noise\nseed 7\n" "seed 7\n" ""
                     andalso not (LibHosts.outputOK "kat" "seed 8\n" "seed 7\n" ""))
      val () = check ("fingerprint oracle", LibHosts.outputOK "core" "PASS a\nfingerprint ABC\n" "" "ABC"
                     andalso not (LibHosts.outputOK "core" "PASS a\nfingerprint ABD\n" "" "ABC"))
      val ls = Expectations.parse ("deviations", "native:mlton | random.* | HOST-BUG | planted\n"
                  ^ "native:mlton | unit.* | HOST-FLAKY | intermittent\nnative:polyml | other | HOST-BUG | another host\n")
      val () = check ("matching failure uses deviation", null (LibHosts.unused ls "mlton" ["random.kat"]))
      val () = check ("stale strict deviation", length (LibHosts.unused ls "mlton" []) = 1)
      val () = check ("another host's deviation", null (LibHosts.unused ls "smlnj32" []))
      val () = check ("library inventory", length LibHosts.tests = 32)
      val () = check ("C frontend host coverage", List.exists (fn t : LibHosts.test =>
        #label t = "language.c.frontend" andalso #libraries t = ["unit", "language/c"]
        andalso #source t = "tests/lib/language/c/frontend.sml") LibHosts.tests)
      val () = check ("C target host coverage", List.exists (fn t : LibHosts.test =>
        #label t = "language.c.target" andalso #libraries t = ["unit", "language/c"]
        andalso #source t = "tests/lib/language/c/target.sml") LibHosts.tests)
      val () = check ("FFI model host coverage", List.exists (fn t : LibHosts.test =>
        #label t = "ffi.model.policy" andalso #libraries t = ["unit","unicode","json","language/c","ffi/model"]
        andalso #source t = "tests/lib/ffi/model/policy.sml") LibHosts.tests)
      val () = check ("C analysis host coverage", List.exists (fn t : LibHosts.test =>
        #label t = "language.c.analysis" andalso #source t = "tests/lib/language/c/analysis.sml") LibHosts.tests)
      val () = check ("target profile host coverage", List.exists (fn t : LibHosts.test =>
        #label t = "ffi.model.target" andalso #source t = "tests/lib/ffi/model/target.sml") LibHosts.tests)
    in () end

  fun command ["host-adapter-checks"] = SOME one
    | command _ = NONE
  val tree = Test.tag "check" (Test.tag "quick" (Test.tag "covers:tests/runner/hosts.sml"
    (Test.tag "covers:tests/runner/libhosts.sml" (Test.tag "covers:tests/runner/hostchecks.sml"
      (Test.describe "runner" [LibHosts.job ("host-adapter", ["host-adapter-checks"], [], 256)])))))
end
