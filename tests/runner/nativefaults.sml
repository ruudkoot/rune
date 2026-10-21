(* Faults at the native launcher's process/cache boundary. Fake compilers
   are fixtures; the real SML launcher and supervisor decide every verdict. *)
structure NativeFaults =
struct
  open Sh
  fun one () =
    let
      val dir = run ^ "/native-faults"
      val () = mkdirs dir
      fun assert (name, ok) = if ok then () else say ("FAIL native fault: " ^ name ^ "\n")
      fun script (path, body) =
        (write (path, "#!/bin/sh\n" ^ body ^ "\n");
         Posix.FileSys.chmod (path, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]))
      val input = dir ^ "/input.rbc"
      val () = write (input, "compiler fixture input\n")
      val oddName = dir ^ "/hash with spaces\nand newline.rbc"
      val () = write (oddName, "\000\255\001checksum boundary\n")
      val () = assert ("hash tool preserves binary input and pathname", NativeVM.checksum oddName = NativeVM.smlChecksum oddName)
      val hashTools = dir ^ "/hash-tools"
      val () = mkdirs hashTools
      fun hashCase (name, body, path, extra) =
        let val () = script (hashTools ^ "/sha256sum", body)
            val status = Children.exec NativeChecks.limits (extra o setEnv ("PATH", path))
              {cmd = [fromRoot "bin/runevm", fromRoot "bin/rune-native-check.rbc", "native-checksum", oddName],
               dir = SOME root, stdin = "", stdout = dir ^ "/" ^ name ^ ".out", stderr = dir ^ "/" ^ name ^ ".err", timeout = 30}
        in assert (name, status = 0 andalso read (dir ^ "/" ^ name ^ ".out") = NativeVM.smlChecksum oddName ^ "\n") end
      val () = hashCase ("hash-missing-tool", "exit 1", dir ^ "/no-tools", fn e => e)
      val () = hashCase ("hash-malformed-tool-output", "printf 'bad hash\\n'", hashTools, fn e => e)
      val () = hashCase ("hash-tool-failure", "exit 7", hashTools, fn e => e)
      val () = hashCase ("hash-unwritable-temporary", "exit 1", env ("PATH", ""), setEnv ("TMPDIR", dir ^ "/missing-parent"))
      val args = "while [ $# -gt 0 ]; do case $1 in -o) output=$2; shift 2 ;; *) shift ;; esac; done\n"
      fun compiler body payload = args ^ body ^ "\ncat > \"$output\" <<'NATIVE_PROGRAM'\n#!/bin/sh\n" ^ payload
                                    ^ "\nNATIVE_PROGRAM\nchmod +x \"$output\"\n"
      fun attempt (name, body, timeout, cap) =
        let
          val here = dir ^ "/" ^ name
          val () = mkdirs here
          val cc = here ^ "/compiler with spaces"
          val () = script (cc, body)
          val cache = here ^ "/cache"
          val () = rmTree cache
          val () = if name = "stale-cache" then
              (mkdirs cache; script (cache ^ "/" ^ NativeVM.checksum input, "" );
               write (cache ^ "/" ^ NativeVM.checksum input, "")) else ()
          val env = setEnv ("RUNEOPT", cc) (setEnv ("RUNEOPT_CACHE", cache) (Posix.ProcEnv.environ ()))
          val result = ref NONE : Supervisor.result option ref
          val command = {program = fromRoot "bin/runevm",
            args = [fromRoot "bin/runevm", fromRoot "bin/runevm-native.rbc", root, input],
            env = env, dir = root, stdin = "/dev/null", stdout = here ^ "/stdout", stderr = here ^ "/stderr",
            timeout = Time.fromSeconds timeout, cap = cap, cost = 0.0, cpus = 1, memory = 100,
            pools = [], exclusive = false, failedLast = false, deps = []} : Supervisor.command
          val () = Supervisor.run {commands = Vector.fromList [command], cpus = 1, memory = 100,
              finished = fn (_, r) => (result := SOME r; Supervisor.Passed), tick = fn _ => ()}
        in (valOf (!result), here, cache) end
      val (pass, _, _) = attempt ("passes", compiler "" "printf 'PASS native\\n'", 10, 1000000)
      val () = assert ("valid native executable", #outcome pass = Supervisor.Exited 0 andalso not (#leaked pass))
      val (stale, _, cache) = attempt ("stale-cache", compiler "" "printf 'PASS native\\n'", 10, 1000000)
      val () = assert ("empty stale cache is regenerated", #outcome stale = Supervisor.Exited 0
                        andalso NativeVM.executable (cache ^ "/" ^ NativeVM.checksum input))
      val (missing, _, cache) = attempt ("no-executable", "exit 0", 10, 1000000)
      val () = assert ("zero exit without executable rejected", #outcome missing = Supervisor.Exited 2)
      val () = assert ("failed producer does not poison cache", null (entries cache))
      val (failed, here, cache) = attempt ("compiler-fails", "printf 'runeopt: planted failure\\n\\n' >&2; exit 7", 10, 1000000)
      val () = assert ("compiler failure", #outcome failed = Supervisor.Exited 2 andalso null (entries cache))
      val () = assert ("diagnostics keep blank lines", read (here ^ "/stderr") = "runevm: planted failure\n\n")
      val (crash, _, _) = attempt ("crashes", compiler "" "printf 'PASS native\\n'; kill -SEGV $$", 10, 1000000)
      val () = assert ("PASS before crash (" ^ Supervisor.outcomeName (#outcome crash) ^ ", " ^ Time.toString (#wall crash) ^ " s)", #outcome crash = Supervisor.Signalled 11)
      val (flood, _, _) = attempt ("floods", compiler "" "exec yes FLOOD", 10, 10000)
      val () = assert ("output flood (" ^ Supervisor.outcomeName (#outcome flood) ^ ", " ^ Time.toString (#wall flood) ^ " s, " ^ Int.toString (#outputBytes flood) ^ " bytes)", case #outcome flood of Supervisor.Capped => true | Supervisor.Signalled _ => true | _ => false)
      val (loop, _, _) = attempt ("compiler-loops", "printf 'PASS compiler\\n'; exec sleep 30", 1, 1000000)
      val () = assert ("compiler timeout", #outcome loop = Supervisor.TimedOut)
      val (leak, _, _) = attempt ("compiler-leaks", compiler "sleep 30 &" "printf 'PASS native\\n'", 10, 1000000)
      val () = assert ("compiler descendant remains supervised", #outcome leak = Supervisor.Exited 0 andalso #leaked leak)
      val badAssembly = dir ^ "/corrupt.rasm"
      val () = write (badAssembly, "function broken 0 1\n  NO_SUCH_OPCODE\n")
      val refused = ((BytecodeFixture.assemble {opdefs = fromRoot "runtime/stack/opcodes.def",
                        primdefs = fromRoot "runtime/prims.def", listing = badAssembly}; false)
                     handle BytecodeFixture.Bad _ => true)
      val () = assert ("corrupt assembly is refused", refused)
      fun checker (name, checkRoot, envf, args, message) =
        let
          val here = dir ^ "/" ^ name
          val () = mkdirs here
          val status = Children.exec NativeChecks.limits
            (setEnv ("RUNE_TEST_ROOT", checkRoot) o setEnv ("RUNE_TEST_RUN", here) o envf)
            {cmd = fromRoot "bin/rune-native-check" :: args, dir = SOME checkRoot, stdin = "",
             stdout = here ^ "/stdout", stderr = here ^ "/stderr", timeout = 120}
        in assert (name, status = 0 andalso String.isSubstring message (read (here ^ "/stdout"))) end
      val countVM = dir ^ "/wrong-count"
      val () = script (countVM, quote (fromRoot "bin/runevm-stack") ^ " \"$@\"\ns=$?\nprintf 'planted wrong count\\n' >&2\nexit $s")
      val hello = fromRoot "tests/out/dec.val_simple.rbc"
      val () = checker ("wrong-count-detected", root, setEnv ("RUNE_TEST_STACK_VM", countVM),
                        ["native-counts", hello], "FAIL native " ^ hello ^ ": counts ")
      val fakeTools = dir ^ "/tools"
      val () = mkdirs fakeTools
      val () = script (fakeTools ^ "/addr2line", "while read address; do printf 'planted-wrong-location:1\\n'; done")
      val () = checker ("wrong-location-detected", root, setEnv ("PATH", fakeTools ^ ":" ^ env ("PATH", "")),
                        ["native-debug", hello], "addr2line: expected ")
      val fixture = dir ^ "/wrong-golden"
      val () = mkdirs (fixture ^ "/tests/lang")
      val () = mkdirs (fixture ^ "/tests/opt")
      fun link (target, path) = if exists path then () else Posix.FileSys.symlink {old = fromRoot target, new = path}
      val () = List.app (fn path => link (path, fixture ^ "/" ^ path)) ["bin", "lib", "runtime"]
      val () = link ("tests/lang/rt.save_first.sml", fixture ^ "/tests/lang/rt.save_first.sml")
      val () = link ("tests/opt/foreign.sml", fixture ^ "/tests/opt/foreign.sml")
      val () = write (fixture ^ "/tests/lang/rt.save_first.restore", "planted wrong expected output\n")
      val () = checker ("wrong-golden-detected", fixture, fn e => e, ["native-images"], "VM to native image: ")
    in () end
end
