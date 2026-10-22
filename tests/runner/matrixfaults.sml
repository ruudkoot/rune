(* Controller faults: diagnostics, dependency discovery, alternatives and
   process endings must not manufacture a successful host verdict. *)
structure MatrixFaults =
struct
  open Sh
  fun need (name, ok) = if ok then () else say ("FAIL matrix controller: " ^ name ^ "\n")
  fun script (file, body) =
    (write (file, "#!/bin/sh\n" ^ body ^ "\n");
     Posix.FileSys.chmod (file, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]))
  fun one () =
    let
      val dir = run ^ "/matrix-faults"
      val () = mkdirs dir
      val () = need ("configuration expansion", length (MatrixModel.expand "all,xc2") = 18
                andalso length (MatrixModel.expand "windows,portability") = 9)
      val () = List.app (fn (host, text) => need (host ^ " located error",
                    MatrixProbe.errorLines host text "source with spaces.sml" = [7]))
        [("mlton", "Error: /a/source with spaces.sml 7.3-7.9.\n"),
         ("smlnj-legacy", "/a/source with spaces.sml:7.3-7.9 Error: planted\n"),
         ("polyml", "/a/source with spaces.sml:7: error: planted\n"),
         ("mlkit", "source with spaces.sml, line 7, column 3:\nerror\n")]
      val code = "(* Hidden.Name (* Nested.No *) *) val x = \"Fake.Path.value\"; let (* gap *) open BinIO in StreamIO.input x end"
      val () = need ("dependencies ignore strings/comments", HostLaws.dependencies code = ["StreamIO", "BinIO"])
      val rejected = ((SmlScan.tokens "(* missing"; false) handle SmlScan.Bad _ => true)
      val () = need ("checker lexical error is explicit", rejected)
      val () = need ("warnings do not drop a library file", null (MatrixProbe.errorLines "smlnj-legacy"
                    "source with spaces.sml:7.3-7.9 Warning: nonexhaustive match\n" "source with spaces.sml"))
      val () = need ("Posix.Error check labels are not compiler diagnostics", not (MatrixProbe.sessionError "smlnj-legacy"
                   ["source.sml"] "PASS Posix.Error:POSIX_ERROR/matches\nSUMMARY 1 checks, 0 failed\n"))
      val decoded = MatrixModel.parseRow false "native:mlkit@4.7.25\tnative\tmlkit\t/compiler\t/library\t"
      val () = need ("resolved configuration protocol", #id decoded = "native:mlkit@4.7.25" andalso #vm decoded = "/library"
                 andalso MatrixModel.row decoded = "native:mlkit@4.7.25\tnative\tmlkit\t/compiler\t/library\t\n")
      val programs = ["ARRAY", "ARRAY2", "LIST", "LIST_PAIR", "WORD", "WORD8"]
      val patterns = [("^LIST$", ["LIST"]), ("^(LIST|WORD)", ["LIST", "LIST_PAIR", "WORD", "WORD8"]),
        ("ARRAY[0-9]?", ["ARRAY", "ARRAY2"]), ("(?i)^list$", ["LIST"]), ("^WORD(?!8)", ["WORD"]),
        ("^.*_(PAIR)$", ["LIST_PAIR"]), ("^ABSENT$", [])]
      val () = List.app (fn (pattern, expected) => need ("program regex " ^ pattern,
                  ProgramSelect.filter {pattern = pattern, names = programs, directory = dir ^ "/regex"} = expected)) patterns
      val () = need ("malformed regex is explicit", ((ProgramSelect.filter {pattern = "[", names = programs,
                 directory = dir ^ "/regex"}; false) handle ProgramSelect.Invalid _ => true))
      val label = "SIG.member/law-1@S"
      val text = "val () = Check.laws [\n  (\"" ^ label ^ "\", fn () => bad)\n]\n"
      val p = HostLaws.splitProgram "probe" text
      val () = need ("law split preserves label", List.map (fn e : HostLaws.entry => #label e) (#entries p) = [label])
      val calls = ref 0
      fun fakeBuild (_, _) : MatrixHost.result =
        let val () = calls := !calls + 1
            fun again _ = (0, "LAW " ^ label ^ "\nPASS " ^ label ^ ": good\nlaws: 1 pass, 0 fail\n")
        in if !calls = 1 then {built = false, status = 0, output = "PASS fake\n",
              messages = dir ^ "/probe.sml:2.1 Error: bad entry\n", again = again}
           else {built = true, status = 0, output = #2 (again []), messages = "", again = again} end
      val recovered = HostLaws.runProgram {host = "smlnj-legacy", program = p,
            alternatives = [(label, ["  (\"" ^ label ^ "\", fn () => good)\n"])], lacks = fn _ => [],
            directory = dir, library = [], build = fakeBuild}
      val () = need ("zero-exit static error takes alternative", !calls = 2 andalso #alternatives recovered = [label]
                    andalso List.exists (String.isPrefix ("PASS " ^ label)) (#results recovered))
      val () = need ("PASS before failure is rejected", ((HostLaws.finish (7, "LAW " ^ label ^ "\nPASS " ^ label ^ ": good\nlaws: 1 pass, 0 fail\n")
                   (fn _ => (0, "")); false) handle HostLaws.Failed _ => true))
      val failedLaw = "LAW " ^ label ^ "\nFAIL " ^ label ^ ": counterexample\nlaws: 0 pass, 1 fail\n"
      val (reported, _) = HostLaws.finish (1, failedLaw) (fn _ => (0, ""))
      val () = need ("reported law failure is not a crashed controller", String.isSubstring ("FAIL " ^ label) reported)
      val (reported, _) = HostLaws.finishWith 255 (255, failedLaw) (fn _ => (0, ""))
      val () = need ("MLKit uses 255 for ordinary property failure", String.isSubstring ("FAIL " ^ label) reported)
      val () = need ("MLKit PASS before failure is rejected", ((HostLaws.finishWith 255 (255,
                    "LAW " ^ label ^ "\nPASS " ^ label ^ ": good\nlaws: 1 pass, 0 fail\n") (fn _ => (0, "")); false)
                      handle HostLaws.Failed _ => true))
      val devs = [{config = "native:mlton", label = "SIG.*", category = "HOST-BUG", reason = "planted"},
                  {config = "native:mlton", label = "other", category = "HOST-FLAKY", reason = "optional"}] : HostLaws.deviation list
      val () = need ("strict unused deviation", length (HostLaws.stale [("mlton", "PASS " ^ label ^ ": good\n")] devs) = 1)
      val () = need ("matching failure uses deviation", null (HostLaws.stale [("mlton", "FAIL " ^ label ^ ": bad\n")] devs))
      fun probeFailure body =
        let val compiler = dir ^ "/broken-host"
            val () = script (compiler, body)
            val result = ((MatrixProbe.probe {host = {name = "smlnj-legacy", program = compiler, library = ""},
                     names = ["Int"], directory = dir ^ "/broken-probe", signatureProbe = false}; false)
                    handle MatrixProbe.Failed _ => true)
        in need ("broken zero-exit capability probe", result) end
      val () = probeFailure "printf 'probe.sml:1.1 Error: failed sanity\\nPASS fake\\n'"
      val () = probeFailure "printf 'input.sml:1.1 Error: failed compiler\\nPASS fake\\n'"
      val missing = dir ^ "/no-executable"
      val () = script (missing, "exit 0")
      val source = dir ^ "/fixture.sml"
      val () = write (source, "val () = ()\n")
      val binary = dir ^ "/binary"
      val () = mkdirs binary
      val () = script (binary ^ "/program", "printf 'PASS stale\\n'")
      val result = MatrixHost.build {host = {name = "mlton", program = missing, library = ""}, name = "program", sources = [source],
            directory = binary, runDirectory = dir, input = "", timeout = 5, memory = 100, int64 = false}
      val () = need ("stale executable does not repair failed producer", not (#built result) andalso #status result <> 0 andalso #output result = "")
      val fixture = dir ^ "/collector"
      val out = fixture ^ "/host-laws"
      val () = mkdirs (out ^ "/programs")
      val () = List.app (fn (name, label) => write (out ^ "/programs/" ^ name ^ ".sml",
          "val () = Check.laws [\n  (\"" ^ label ^ "\", fn () => Prop.assert true)\n]\n"))
              [("A", "P.one/law-1@Int"), ("B", "P.two/law-1@Int")]
      val () = write (out ^ "/selected.txt", "A\nB\n")
      val fake = fixture ^ "/sml"
      fun compiler failedLibrary otherLabel =
        "for file in \"$@\"; do case $file in\n"
        ^ "*/library.sml) " ^ (if failedLibrary then "exit 9" else "printf 'library built\\n'; exit 0") ^ " ;;\n"
        ^ "*/A.sml) exit 7 ;;\n"
        ^ "*/B.sml) printf 'LAW P.two/law-1@Int\\nPASS " ^ otherLabel
        ^ ": good\\nlaws: 1 pass, 0 fail\\n'; exit 0 ;;\nesac; done\nexit 0"
      fun collect label =
        let val status = Children.exec {addressSpace = SOME (1024 * 1024 * 1024), cpuTime = SOME 60,
                                        fileSize = SOME (1024 * 1024), core = SOME 0}
              (setEnv ("RUNE_TEST_RUN", fixture) o setEnv ("SMLNJ", fake))
            {cmd = [fromRoot "bin/rune-laws-hosts", "host-laws-collect", "smlnj-legacy"], dir = SOME root,
             stdin = "", stdout = fixture ^ "/" ^ label ^ ".out", stderr = fixture ^ "/" ^ label ^ ".err", timeout = 60}
        in need (label ^ " collector completed", status = 0);
           (read (out ^ "/smlnj-legacy.results"), read (out ^ "/smlnj-legacy/controller-errors.txt")) end
      val () = script (fake, compiler false "P.two/law-1@Int")
      val (output, errors) = collect "early-program-failure"
      val () = need ("failed law program preserves later programs", length (lines output) = 2
                      andalso String.isSubstring "NOT RUN P.one/law-1@Int" output
                      andalso String.isSubstring "PASS P.two/law-1@Int" output
                      andalso String.isSubstring "exit 7" errors)
      val () = need ("collector error cannot compare successfully", ((HostLaws.compareFiles out ["smlnj-legacy"]; false)
                                                             handle HostLaws.Failed _ => true))
      val () = script (fake, compiler false "P.unselected/law-1@Int")
      val (output, errors) = collect "unselected-verdict"
      val () = need ("unselected PASS label rejected", length (lines output) = 2
                   andalso not (String.isSubstring "PASS " output) andalso String.isSubstring "unselected label" errors)
      val () = script (fake, compiler true "P.two/law-1@Int")
      val (output, errors) = collect "library-producer-failure"
      val () = need ("failed library accounts for every selected law", length (lines output) = 2
                    andalso List.all (String.isPrefix "NOT BUILT ") (lines output)
                    andalso String.isSubstring "library producer" errors)
    in () end
end
