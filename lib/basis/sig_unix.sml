(* Running another program and talking to it: a child process with a pipe
   each way.

   `execute` starts a program and gives a `proc`, from which the streams are
   taken: what the child writes is read through `textInstreamOf`, and what it
   is to read is written through `textOutstreamOf`. `reap` waits for it and
   is its status. This is `Posix.Process`'s fork, exec and waitpid put
   together, with the pipes made and the descriptors handed over; the
   system starts the program itself, without a fork, which Windows does
   not have.

   The two type variables of `proc` say what its streams are, text or binary;
   they are decided by which of the four functions is used on it, so a
   top-level binding of a `proc` usually needs a type annotation, the value
   restriction being what it is.

   Area: The operating system

   Status: optional

   See also: `POSIX_PROCESS`, `OS_PROCESS`, `TEXT_IO`, `BIN_IO`, `POSIX`

   Erratum: `UNIX/opaque-in-the-page`. The page declares `structure Unix :>
   UNIX`, so `signal` is abstract there; the suite checks that it is
   `Posix.Signal.signal` and that `exit_status` is
   `Posix.Process.exit_status`, which the page requires where both structures
   exist *)
signature UNIX =
sig
  (* The type of a running child process, with the streams that talk to it.

     The first type variable is the stream the child's output is read
     through, the second the stream its input is written through. *)
  type ('a, 'b) proc

  (* The type of a signal, the one of `Posix.Signal`. *)
  type signal

  (* How a process ended, or why it stopped; the `exit_status` of `Posix.Process`. *)
  datatype exit_status
    = W_EXITED                   (* it ended of itself, successfully *)
    | W_EXITSTATUS of Word8.word (* it ended of itself, with that status *)
    | W_SIGNALED of signal       (* a signal ended it *)
    | W_STOPPED of signal        (* a signal stopped it; it has not ended *)

  (* `fromStatus st` is what the status `st` says about how the process ended. *)
  val fromStatus : OS.Process.status -> exit_status

  (* `executeInEnv (path, args, env)` starts the program at `path` with the arguments `args` and the environment `env`.

     The child gets a pipe each way; the parent's ends are closed when it
     runs another program, so a later child does not hold them open.

     Raises: `OS.SysErr` if the child cannot be made.

     Implementation: `Unix.executeInEnv/exec-failure-is-126`. A child whose
     `exec` fails ends with the status 126, as the page asks; that is what a
     `reap` of it reports, rather than an exception in the parent. On
     Windows, which starts a program without a child of this one's and
     knows at once that it cannot be run, this raises `OS.SysErr`, which
     the page allows as well.

     Pinned by: `Unix.executeInEnv/no-such-program`,
     `Unix.execute/no-such-program` *)
  val executeInEnv : string * string list * string list -> ('a, 'b) proc

  (* `execute (path, args)` is `executeInEnv` with the environment this process has.

     Raises: `OS.SysErr` if the child cannot be made.

     Reading: `Unix.execute/current-directory`. The page does not say which
     directory the child runs in; it is this process's current one.

     Pinned by: `Unix.execute/directory` *)
  val execute : string * string list -> ('a, 'b) proc

  (* `textInstreamOf pr` is the text stream that what `pr` writes is read from. *)
  val textInstreamOf : (TextIO.instream, 'a) proc -> TextIO.instream

  (* `binInstreamOf pr` is the binary stream that what `pr` writes is read from. *)
  val binInstreamOf : (BinIO.instream, 'a) proc -> BinIO.instream

  (* `textOutstreamOf pr` is the text stream that `pr` reads what is written to it from. *)
  val textOutstreamOf : ('a, TextIO.outstream) proc -> TextIO.outstream

  (* `binOutstreamOf pr` is the binary stream that `pr` reads what is written to it from. *)
  val binOutstreamOf : ('a, BinIO.outstream) proc -> BinIO.outstream

  (* `streamsOf pr` is the pair of the text streams of `pr`. *)
  val streamsOf : (TextIO.instream, TextIO.outstream) proc -> TextIO.instream * TextIO.outstream

  (* `reap pr` closes the streams of `pr`, waits for it to end, and is its status.

     Reading: `Unix.reap/status-is-remembered`. The status is kept, so
     reaping the same process again gives the same answer rather than
     failing. A child that is merely stopped does not end the wait, since
     `Posix.Process.W.untraced` is not asked for.

     Raises: `OS.SysErr` if the wait fails. *)
  val reap : ('a, 'b) proc -> OS.Process.status

  (* `kill (pr, s)` sends the signal `s` to the child `pr`.

     Raises: `OS.SysErr` if the signal may not be sent. *)
  val kill : ('a, 'b) proc * signal -> unit

  (* `exit st` ends this program with the status `st`.

     Reading: `Unix.exit/flushes`. It runs the `OS.Process.atExit` actions
     and then leaves through the VM's exit, which flushes every file; that is
     taken to satisfy "flushes and closes all I/O streams". *)
  val exit : Word8.word -> 'a
end
