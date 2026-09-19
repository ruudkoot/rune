(* requires: Unix Posix OS TextIO BinIO *)
(* uses: fn/posix_child.sml *)
(* Unix (signature UNIX). Expected values follow the text of
   https://smlfamily.github.io/Basis/unix.html. The programs run are
   /bin/sh, /bin/echo, /bin/cat and /usr/bin/env ("Typically, the cmd
   argument will be a full pathname"); for Unix.execute (cmd, args), args
   are the arguments after the program's name. Every process is reaped.

   The sections that use Posix need Unix.signal = Posix.Signal.signal ("an
   implementation providing the Posix module would probably equate the
   signal and Posix.Signal.signal types") and a child made with
   Posix.Process.fork. *)
structure TestUnix =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val w8 = PosixChild.w8
  fun showStatus Unix.W_EXITED = "W_EXITED"
    | showStatus (Unix.W_EXITSTATUS w) = "W_EXITSTATUS " ^ Word8.fmt StringCvt.DEC w
    | showStatus (Unix.W_SIGNALED _) = "W_SIGNALED _"
    | showStatus (Unix.W_STOPPED _) = "W_STOPPED _"
  val eqSt = T.eq showStatus

  type text = (TextIO.instream, TextIO.outstream) Unix.proc
  fun shell (script : string) : text = Unix.execute ("/bin/sh", ["-c", script])
  (* The status of the process, as the exit_status that fromStatus gives. *)
  fun status (p : ('a, 'b) Unix.proc) : Unix.exit_status = Unix.fromStatus (Unix.reap p)
  fun output (p : text) : string =
    let val s = TextIO.inputAll (Unix.textInstreamOf p) in ignore (Unix.reap p); s end

  (* ---- execute, executeInEnv ---- *)
  val () = eqS ("Unix.execute/echo", "hello world\n",
                fn () => output (Unix.execute ("/bin/echo", ["hello", "world"])))
  val () = eqS ("Unix.execute/argument-list", "2:a:b c:",
                fn () => output (Unix.execute ("/bin/sh", ["-c", "printf '%s:%s:%s:' $# \"$1\" \"$2\"", "sh", "a", "b c"])))
  (* "it inherits the calling process's environment" *)
  val () = eqB ("Unix.execute/environment", true,
                fn () => SOME (output (shell "printf %s \"$PATH\"")) = OS.Process.getEnv "PATH")
  (* It runs in the current directory. *)
  val () = eqS ("Unix.execute/directory", "here\n",
                fn () => (PosixChild.write ("unix-here.txt", "here\n"); output (Unix.execute ("/bin/cat", ["unix-here.txt"]))))
  (* "asks the operating system to execute the program named by the string
     cmd with the argument list args and the environment env" *)
  val () = eqS ("Unix.executeInEnv/environment", "A=1\nB=two words\n",
                fn () => output (Unix.executeInEnv ("/usr/bin/env", [], ["A=1", "B=two words"])))
  val () = eqS ("Unix.executeInEnv/empty-environment", "",
                fn () => output (Unix.executeInEnv ("/usr/bin/env", [], [])))
  val () = eqS ("Unix.executeInEnv/arguments", "x y\n",
                fn () => output (Unix.executeInEnv ("/bin/echo", ["x", "y"], [])))
  (* "If the child process fails to execute the command (i.e., the execve
     call fails), then it should exit with a status code of 126", or
     executeInEnv raises OS.SysErr, "the case where cmd does not name an
     executable file" being one reason. *)
  val () = eqB ("Unix.execute/no-such-program", true,
                fn () => status (Unix.execute ("./no-such-program", []) : text) = Unix.W_EXITSTATUS (w8 126)
                         handle OS.SysErr _ => true)
  val () = eqB ("Unix.executeInEnv/no-such-program", true,
                fn () => status (Unix.executeInEnv ("./no-such-program", [], []) : text) = Unix.W_EXITSTATUS (w8 126)
                         handle OS.SysErr _ => true)

  (* ---- streams: textInstreamOf and binInstreamOf are "connected to the
     standard output stream of the process pr", textOutstreamOf and
     binOutstreamOf "to the standard input stream" ---- *)
  val () = eqS ("Unix.textOutstreamOf/to-cat", "line one\nline two\n",
                fn () => let
                           val p : text = Unix.execute ("/bin/cat", [])
                           val out = Unix.textOutstreamOf p
                         in
                           TextIO.output (out, "line one\nline two\n");
                           TextIO.closeOut out;
                           output p
                         end)
  val () = eqS ("Unix.textInstreamOf/lines", "1\n2\n3\n",
                fn () => output (shell "echo 1; echo 2; echo 3"))
  (* "equivalent to (textInstream pr, textOutstream pr)": a conversation. *)
  val () = T.eq (T.list T.string) ("Unix.streamsOf/conversation", ["[hi]\n", "[there]\n"],
                fn () => let
                           val p = shell "while read x; do echo \"[$x]\"; done"
                           val (ins, out) = Unix.streamsOf p
                           fun ask s = (TextIO.output (out, s ^ "\n"); TextIO.flushOut out;
                                        getOpt (TextIO.inputLine ins, ""))
                           val r = [ask "hi", ask "there"]
                         in
                           TextIO.closeOut out; ignore (Unix.reap p); r
                         end)
  val () = T.eq (T.list T.int) ("Unix.binInstreamOf/bytes", [0x61, 0x62, 0x0a],
                fn () => let
                           val p : (BinIO.instream, BinIO.outstream) Unix.proc = Unix.execute ("/bin/echo", ["ab"])
                           val v = BinIO.inputAll (Unix.binInstreamOf p)
                         in
                           ignore (Unix.reap p); List.map Word8.toInt (Word8Vector.foldr op :: [] v)
                         end)
  val () = T.eq (T.list T.int) ("Unix.binOutstreamOf/to-cat", [0, 1, 128, 255, 10],
                fn () => let
                           val p : (BinIO.instream, BinIO.outstream) Unix.proc = Unix.execute ("/bin/cat", [])
                           val out = Unix.binOutstreamOf p
                           val () = BinIO.output (out, Word8Vector.fromList (List.map Word8.fromInt [0, 1, 128, 255, 10]))
                           val () = BinIO.closeOut out
                           val v = BinIO.inputAll (Unix.binInstreamOf p)
                         in
                           ignore (Unix.reap p); List.map Word8.toInt (Word8Vector.foldr op :: [] v)
                         end)
  (* The two kinds mixed: bytes in, text out. *)
  val () = eqS ("Unix.binOutstreamOf/text-back", "abc\n",
                fn () => let
                           val p : (TextIO.instream, BinIO.outstream) Unix.proc = Unix.execute ("/bin/cat", [])
                           val out = Unix.binOutstreamOf p
                         in
                           BinIO.output (out, Word8Vector.fromList (List.map Word8.fromInt [0x61, 0x62, 0x63, 0x0a]));
                           BinIO.closeOut out;
                           TextIO.inputAll (Unix.textInstreamOf p) before ignore (Unix.reap p)
                         end)

  (* ---- reap: "closes the input and output streams associated with pr,
     and then suspends the current process until the system process
     corresponding to pr terminates. It returns the exit status given by pr
     when it terminated. If reap is applied again to pr, it should
     immediately return the previous exit status." ---- *)
  val () = eqB ("Unix.reap/success", true, fn () => OS.Process.isSuccess (Unix.reap (shell "exit 0")))
  val () = eqB ("Unix.reap/failure", false, fn () => OS.Process.isSuccess (Unix.reap (shell "exit 3")))
  val () = eqSt ("Unix.reap/status", Unix.W_EXITSTATUS (w8 3), fn () => status (shell "exit 3"))
  val () = T.eq (T.pair (showStatus, showStatus)) ("Unix.reap/twice", (Unix.W_EXITSTATUS (w8 5), Unix.W_EXITSTATUS (w8 5)),
                fn () => let val p = shell "exit 5" val s1 = status p in (s1, status p) end)
  val () = eqB ("Unix.reap/twice-same-status", true,
                fn () => let val p = shell "exit 0" val s1 = Unix.reap p in OS.Process.isSuccess s1 andalso OS.Process.isSuccess (Unix.reap p) end)
  (* It closes the input of the process, which cat reads to its end. *)
  val () = eqB ("Unix.reap/closes-input", true, fn () => OS.Process.isSuccess (Unix.reap (Unix.execute ("/bin/cat", []) : text)))
  (* It waits for the process to end. *)
  val () = eqS ("Unix.reap/waits", "done",
                fn () => (ignore (Unix.reap (shell "sleep 1; printf done > unix-waits.txt"));
                          PosixChild.slurp "unix-waits.txt"))

  (* ---- fromStatus: "returns a concrete view of the given status" ---- *)
  val () = eqSt ("Unix.fromStatus/success", Unix.W_EXITED, fn () => Unix.fromStatus OS.Process.success)
  val () = eqB ("Unix.fromStatus/failure", true,
                fn () => case Unix.fromStatus OS.Process.failure of Unix.W_EXITSTATUS w => w <> w8 0 | _ => false)
  val () = eqSt ("Unix.fromStatus/system", Unix.W_EXITSTATUS (w8 4), fn () => Unix.fromStatus (OS.Process.system "exit 4"))
  val () = eqSt ("Unix.W_EXITED/reap", Unix.W_EXITED, fn () => status (shell "exit 0"))
  val () = eqSt ("Unix.W_EXITSTATUS/reap", Unix.W_EXITSTATUS (w8 255), fn () => status (shell "exit 255"))

  (*<< posix-signal *)
  fun signaled (s : Posix.Signal.signal) (st : Unix.exit_status) =
    case st of Unix.W_SIGNALED s' => s' = s | _ => false
  (* "sends the signal s to the process pr": cat has answered, so it is
     running when the signal comes. *)
  fun running () =
    let
      val p : text = Unix.execute ("/bin/cat", [])
      val (ins, out) = Unix.streamsOf p
    in
      TextIO.output (out, "x\n"); TextIO.flushOut out; ignore (TextIO.inputLine ins); p
    end
  val () = eqB ("Unix.kill/term", true,
                fn () => let val p = running () in Unix.kill (p, Posix.Signal.term); signaled Posix.Signal.term (status p) end)
  val () = eqB ("Unix.kill/kill", true,
                fn () => let val p = running () in Unix.kill (p, Posix.Signal.kill); signaled Posix.Signal.kill (status p) end)
  val () = eqB ("Unix.W_SIGNALED/reap", true,
                fn () => signaled Posix.Signal.term (status (shell "kill -TERM $$")))
  val () = eqB ("Unix.fromStatus/signaled", true,
                fn () => signaled Posix.Signal.hup (Unix.fromStatus (Unix.reap (shell "kill -HUP $$"))))
  (* "Also note that reap should not return until the process being monitored
     has terminated. In particular, implementations should be careful not to
     return if the process has only been suspended." A second process
     continues the first after a second. *)
  val () = eqSt ("Unix.W_STOPPED/reap-waits-for-the-end", Unix.W_EXITSTATUS (w8 5),
                 fn () => let
                            val p = shell "echo $$ > unix-stopped.txt; kill -STOP $$; exit 5"
                            val () = ignore (PosixChild.until (5, fn () =>
                                               (size (PosixChild.slurp "unix-stopped.txt") > 1) handle _ => false))
                            val pid = String.substring (PosixChild.slurp "unix-stopped.txt", 0,
                                                        size (PosixChild.slurp "unix-stopped.txt") - 1)
                            val q = shell ("sleep 1; kill -CONT " ^ pid)
                          in
                            status p before ignore (Unix.reap q)
                          end)
  (*>> posix-signal *)

  (*<< exit *)
  (* exit "executes all actions registered with OS.Process.atExit, flushes
     and closes all I/O streams opened using the Library, then terminates
     the SML process with termination status st": in a child. *)
  fun exitChild () =
    PosixChild.waitBounded (PosixChild.fork (fn () =>
      let val out = TextIO.openOut "unix-exit.txt"
      in
        OS.Process.atExit (fn () => PosixChild.write ("unix-atexit.txt", "ran"));
        TextIO.output (out, "flushed");
        Unix.exit (w8 6)
      end))
  val () = T.eq (T.option PosixChild.showStatus) ("Unix.exit/status", SOME (Posix.Process.W_EXITSTATUS (w8 6)),
                                                  exitChild)
  val () = eqS ("Unix.exit/flushes", "flushed", fn () => PosixChild.slurp "unix-exit.txt")
  val () = eqS ("Unix.exit/runs-atExit", "ran", fn () => PosixChild.slurp "unix-atexit.txt")
  val () = T.eq T.int ("Unix.exit/result-has-any-type", 1, fn () => if T.range (1, 1) = 1 then 1 else Unix.exit (w8 1))
  (*>> exit *)

  val () = List.app (fn f => OS.FileSys.remove f handle _ => ())
                    ["unix-here.txt", "unix-waits.txt", "unix-stopped.txt", "unix-exit.txt", "unix-atexit.txt"]
end
