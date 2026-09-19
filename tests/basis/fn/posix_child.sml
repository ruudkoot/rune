(* Child processes and shell commands for the tests of Posix and Unix
   (posix_*.sml, unix.sml).

   A forked child that runs SML code ends with `leave`, which executes
   /bin/sh to exit with the status: on Poly/ML a forked child that calls
   Posix.Process.exit or OS.Process.exit crashes (5.7.1) or never ends
   (5.9.2), while one that calls exec works everywhere. The checks of exit
   itself call it in the child and wait with `waitBounded`, so that a child
   that does not end is killed and fails its check instead of hanging the
   test.

   Exit statuses are written `w8 3`, times built from an int: a host that
   compiles lib/basis (xc1) cannot type a constant at the Word8 or the
   LargeInt of lib/basis. *)
structure PosixChild =
struct
  structure P = Posix.Process

  val w8 : int -> Word8.word = Word8.fromInt
  fun secs (n : int) = Time.fromSeconds (LargeInt.fromInt n)
  fun ms (n : int) = Time.fromMilliseconds (LargeInt.fromInt n)

  (* leave w: end this process, a child, with the exit status w. *)
  fun leave (w : Word8.word) : 'a =
    P.exec ("/bin/sh", ["sh", "-c", "exit " ^ Word8.fmt StringCvt.DEC w])
    handle _ => P.exit w

  (* spawn f: a child that runs f and leaves with what f returns, or with 99
     when f raises an exception. Nothing the parent has buffered is written
     twice. *)
  fun spawn (f : unit -> Word8.word) : P.pid =
    (TextIO.flushOut TextIO.stdOut;
     case P.fork () of
       NONE => leave (f () handle _ => w8 99)
     | SOME pid => pid)

  (* fork f: a child that runs f, which must not return (it calls exit or
     exec); 98 if it does, 99 if it raises an exception. *)
  fun fork (f : unit -> unit) : P.pid =
    (TextIO.flushOut TextIO.stdOut;
     case P.fork () of
       NONE => ((f (); leave (w8 98)) handle _ => leave (w8 99))
     | SOME pid => pid)

  (* The status of the child pid, once it has ended. *)
  fun status (pid : P.pid) : P.exit_status = #2 (P.waitpid (P.W_CHILD pid, []))

  fun run (f : unit -> Word8.word) : P.exit_status = status (spawn f)

  (* waitBounded pid: the status of the child pid, waiting 5 seconds at
     most; NONE, with the child killed, if it has not ended by then. *)
  fun waitBounded (pid : P.pid) : P.exit_status option =
    let
      val deadline = Time.+ (Time.now (), secs 5)
      fun poll () =
        case P.waitpid_nh (P.W_CHILD pid, []) of
          SOME (_, s) => SOME s
        | NONE =>
            if Time.> (Time.now (), deadline) then
              (P.kill (P.K_PROC pid, Posix.Signal.kill); ignore (P.waitpid (P.W_CHILD pid, [])); NONE)
            else (OS.Process.sleep (ms 10); poll ())
    in
      poll ()
    end

  (* until (seconds, ok): polls ok every 10 ms until it holds, for that many
     seconds at most; whether it held. *)
  fun until (seconds : int, ok : unit -> bool) : bool =
    let
      val deadline = Time.+ (Time.now (), secs seconds)
      fun poll () =
        ok () orelse
        (Time.< (Time.now (), deadline) andalso (OS.Process.sleep (ms 10); poll ()))
    in
      poll ()
    end

  (* stopped pid: the status that waitpid_nh with W.untraced reports for the
     child pid within 5 seconds, or NONE. *)
  fun stopped (pid : P.pid) : P.exit_status option =
    let
      val got = ref NONE
      fun ok () =
        case P.waitpid_nh (P.W_CHILD pid, [P.W.untraced]) of
          SOME (_, s) => (got := SOME s; true)
        | NONE => false
    in
      ignore (until (5, ok)); !got
    end

  (* The file name exists (within 5 seconds). *)
  fun appears (name : string) : bool = until (5, fn () => OS.FileSys.access (name, []))

  fun showSignal (s : Posix.Signal.signal) = "signal " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
  fun showStatus P.W_EXITED = "W_EXITED"
    | showStatus (P.W_EXITSTATUS w) = "W_EXITSTATUS " ^ Word8.fmt StringCvt.DEC w
    | showStatus (P.W_SIGNALED s) = "W_SIGNALED (" ^ showSignal s ^ ")"
    | showStatus (P.W_STOPPED s) = "W_STOPPED (" ^ showSignal s ^ ")"

  (* ---- files and shell commands ---- *)
  fun write (name, s) =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp name =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end

  (* shell cmd: what the command writes on its standard output, without the
     final newline; the command runs with /bin/sh (OS.Process.system). *)
  fun shell (cmd : string) : string =
    let
      val () = ignore (OS.Process.system ("(" ^ cmd ^ ") > posix-shell-out.txt"))
      val s = slurp "posix-shell-out.txt"
    in
      if String.isSuffix "\n" s then String.substring (s, 0, size s - 1) else s
    end

  (* A decimal number that the shell printed, as a word. *)
  fun shellWord (cmd : string) : SysWord.word option =
    StringCvt.scanString (SysWord.scan StringCvt.DEC) (shell cmd)
end
