(* Unix: running a program and talking to it through pipes.

   Implements: UNIX

   Status: optional *)
structure Unix =
struct
  type signal = Posix.Signal.signal
  (* "If an implementation provides both the Posix and Unix structures, then
     Posix.Process.exit_status and exit_status must be the same type." *)
  datatype exit_status = datatype Posix.Process.exit_status

  val fromStatus = Posix.Process.fromStatus

  (* What is left of a process: how to talk to it, and what became of it.
     The two type variables say which kind of stream has been asked for, as
     the specification's signature does; the value is the same either way. *)
  datatype ('a, 'b) proc =
    Proc of {pid : Posix.Process.pid,
             infd : Posix.FileSys.file_desc,     (* its output, which we read *)
             outfd : Posix.FileSys.file_desc,    (* its input, which we write *)
             ins : TextIO.instream option ref,
             outs : TextIO.outstream option ref,
             status : Posix.Process.exit_status option ref}

  local
    fun start (path, args, run) =
      let
        val {infd = fromChildRead, outfd = fromChildWrite} = Posix.IO.pipe ()
        val {infd = toChildRead, outfd = toChildWrite} = Posix.IO.pipe ()
        (* Our ends are closed in every program started later, so that this
           child sees the end of its input when we close ours. *)
        val () = Posix.IO.setfd (fromChildRead, Posix.IO.FD.cloexec)
        val () = Posix.IO.setfd (toChildWrite, Posix.IO.FD.cloexec)
      in
        case Posix.Process.fork () of
          NONE =>
            ((Posix.IO.dup2 {old = toChildRead, new = 0};
              Posix.IO.dup2 {old = fromChildWrite, new = 1};
              Posix.IO.close fromChildRead;
              Posix.IO.close toChildWrite;
              run (path, path :: args))
             handle _ => ();
             (* "If the child process fails to execute the command (i.e.,
                the execve call fails), then it should exit with a status
                code of 126." *)
             Posix.Process.exit (Word8.fromInt 126))
        | SOME pid =>
            (Posix.IO.close fromChildWrite;
             Posix.IO.close toChildRead;
             Proc {pid = pid, infd = fromChildRead, outfd = toChildWrite,
                   ins = ref NONE, outs = ref NONE, status = ref NONE})
      end
  in
    fun executeInEnv (path, args, env) =
      start (path, args, fn (p, a) => Posix.Process.exece (p, a, env))
    fun execute (path, args) =
      start (path, args, fn (p, a) => Posix.Process.exec (p, a))
  end

  fun streamsOf (Proc {infd, outfd, ins, outs, ...}) =
    (case !ins of
       SOME s => s
     | NONE =>
         let val s = TextIO.mkInstream (TextIO.StreamIO.mkInstream
                       (Posix.IO.mkTextReader {fd = infd, name = "<process>", initBlkMode = true}, ""))
         in ins := SOME s; s end,
     case !outs of
       SOME s => s
     | NONE =>
         let val s = TextIO.mkOutstream (TextIO.StreamIO.mkOutstream
                       (Posix.IO.mkTextWriter {fd = outfd, name = "<process>", initBlkMode = true,
                                               appendMode = false, chunkSize = 4096}, IO.NO_BUF))
         in outs := SOME s; s end)

  fun textInstreamOf p = #1 (streamsOf p)
  fun textOutstreamOf p = #2 (streamsOf p)
  fun streamsOf' p = streamsOf p

  fun binInstreamOf (Proc {infd, ...}) =
    BinIO.mkInstream (BinIO.StreamIO.mkInstream
      (Posix.IO.mkBinReader {fd = infd, name = "<process>", initBlkMode = true}, ""))
  fun binOutstreamOf (Proc {outfd, ...}) =
    BinIO.mkOutstream (BinIO.StreamIO.mkOutstream
      (Posix.IO.mkBinWriter {fd = outfd, name = "<process>", initBlkMode = true,
                             appendMode = false, chunkSize = 4096}, IO.NO_BUF))

  fun protect f x = f x

  local
    (* The OS.Process.status of an exit_status, which Posix.Process.fromStatus
       turns back into it. *)
    fun toStatus W_EXITED = 0
      | toStatus (W_EXITSTATUS w) = Word8.toInt w
      | toStatus (W_SIGNALED s) = 256 + s
      | toStatus (W_STOPPED s) = 512 + s
  in
    (* "closes the input and output streams associated with pr, and then
       suspends the current process until the system process corresponding
       to pr terminates"; the status is kept, so that asking twice gives the
       same answer. Without W.untraced, waitpid does not return for a
       process that is only stopped. *)
    fun reap (Proc {pid, infd, outfd, status, ins, outs}) =
      case !status of
        SOME s => toStatus s
      | NONE =>
          let
            val () = (Posix.IO.close outfd handle _ => ())
            val () = (Posix.IO.close infd handle _ => ())
            val (_, s) = Posix.Process.waitpid (Posix.Process.W_CHILD pid, [])
          in status := SOME s; ins := NONE; outs := NONE; toStatus s end
  end

  fun kill (Proc {pid, ...}, signal) = Posix.Process.kill (Posix.Process.K_PROC pid, signal)
  (* "executes all actions registered with OS.Process.atExit, flushes and
     closes all I/O streams opened using the Library, then terminates": the
     VM's exit flushes the files, which is all a stream has to write unless
     its buffer mode was changed (streams are unbuffered, NO_BUF, by
     default). *)
  local
    val exit' = _prim "exit" : int -> 'a
  in
    fun exit (status : Word8.word) = (RuneExit.run (); exit' (Word8.toInt status))
  end
end
