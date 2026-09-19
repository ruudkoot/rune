(* Unix: running a program and talking to it through pipes. *)
structure Unix =
struct
  type signal = Posix.Signal.signal
  datatype exit_status = W_EXITED | W_EXITSTATUS of Word8.word
                       | W_SIGNALED of signal | W_STOPPED of signal

  fun fromStatus Posix.Process.W_EXITED = W_EXITED
    | fromStatus (Posix.Process.W_EXITSTATUS w) = W_EXITSTATUS w
    | fromStatus (Posix.Process.W_SIGNALED s) = W_SIGNALED s
    | fromStatus (Posix.Process.W_STOPPED s) = W_STOPPED s

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
      in
        case Posix.Process.fork () of
          NONE =>
            (Posix.IO.dup2 {old = toChildRead, new = 0};
             Posix.IO.dup2 {old = fromChildWrite, new = 1};
             Posix.IO.close fromChildRead;
             Posix.IO.close toChildWrite;
             run (path, path :: args);
             Posix.Process.exit 0w127)
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

  (* "reaps the process, closing the streams"; the status is kept, so that
     asking twice gives the same answer. *)
  fun reap (Proc {pid, infd, outfd, status, ins, outs}) =
    case !status of
      SOME s => fromStatus s
    | NONE =>
        let
          val () = (Posix.IO.close outfd handle _ => ())
          val () = (Posix.IO.close infd handle _ => ())
          val (_, s) = Posix.Process.waitpid (Posix.Process.W_CHILD pid, [])
        in status := SOME s; ins := NONE; outs := NONE; fromStatus s end

  fun kill (Proc {pid, ...}, signal) = Posix.Process.kill (Posix.Process.K_PROC pid, signal)
  fun exit (status : Word8.word) = Posix.Process.exit status
end
