(* Processes: making them, replacing them, waiting for them and ending them.

   `fork` splits the process in two and is the only way a POSIX program makes
   another; the `exec` family replaces the program that a process is running,
   and never returns. The two together are how a program runs another: fork,
   then exec in the child, then `waitpid` in the parent. `UNIX` wraps that up
   for the common case.

   A child that has ended is remembered until it is waited for, and `wait`
   and `waitpid` report how it ended as an `exit_status`.

   Area: The operating system

   Status: optional

   See also: `POSIX`, `UNIX`, `POSIX_SIGNAL`, `OS_PROCESS`

   Erratum: `POSIX_PROCESS/flexible-types`. The types `signal` and
   `pid` are left flexible here, as on the page; `POSIX` fixes `signal` to
   `Posix.Signal.signal`, and the identities stated only in the text are checked in
   the suite rather than written into the signature.

   Pinned by: `Posix:POSIX/FileSys.uid-is-ProcEnv.uid` *)
signature POSIX_PROCESS =
sig
  (* The type of a signal, the one of `Posix.Signal`. *)
  eqtype signal

  (* The type of the number that names a process.

     Deviation: `Posix.Process.pid/is-an-int`. The specification leaves the
     type abstract; in Rune it is `int`, and the structure is not sealed. *)
  eqtype pid

  (* `wordToPid w` is the process whose number is `w`. *)
  val wordToPid : SysWord.word -> pid

  (* `pidToWord pid` is the number of `pid`. *)
  val pidToWord : pid -> SysWord.word

  (* `fork ()` splits the process in two, and is `NONE` in the child and `SOME` of the child's number in the parent.

     The child has a copy of everything the parent had: its memory, its open
     descriptors and its current directory.

     Raises: `OS.SysErr` if no process can be made. *)
  val fork : unit -> pid option

  (* `exec (path, args)` replaces the running program by the one at `path`, and does not return.

     Raises: `OS.SysErr` if the program cannot be run.

     Reading: `Posix.Process.exec/args-and-path`. The first item of `args` is
     the new program's argument zero and is passed as it stands, not replaced
     by `path`. And `path` is a pathname: a name with no slash in it is not
     looked for along `PATH`, which is what `execp` is for.

     Pinned by: `Posix.Process.exec/args`, `Posix.Process.exec/not-searched` *)
  val exec : string * string list -> 'a

  (* `exece (path, args, env)` is `exec` with `env` as the new program's environment.

     Raises: `OS.SysErr` if the program cannot be run. *)
  val exece : string * string list * string list -> 'a

  (* `execp (file, args)` is `exec` with `file` looked for along `PATH` when it holds no slash.

     Raises: `OS.SysErr` if the program cannot be found or run. *)
  val execp : string * string list -> 'a

  (* Which child `waitpid` is to wait for. *)
  datatype waitpid_arg
    = W_ANY_CHILD        (* any child of this process *)
    | W_CHILD of pid     (* that one child *)
    | W_SAME_GROUP       (* any child in this process's group *)
    | W_GROUP of pid     (* any child in that group *)

  (* How a process ended, or why it stopped. *)
  datatype exit_status
    = W_EXITED                  (* it ended of itself, successfully *)
    | W_EXITSTATUS of Word8.word (* it ended of itself, with that status *)
    | W_SIGNALED of signal      (* a signal ended it *)
    | W_STOPPED of signal       (* a signal stopped it; it has not ended *)

  (* `fromStatus st` is what the status `st` says about how the process ended.

     Implementation: `Posix.Process.fromStatus/status-encoding`. An
     `OS.Process.status` is an `int`: the exit code of a process that ended of
     itself, 256 and the number of the signal that ended it, or 512 and the
     number of the signal that stopped it.

     Pinned by: `Posix.Process.fromStatus/system-*` *)
  val fromStatus : OS.Process.status -> exit_status

  (* The flags that say what `waitpid` is to wait for. *)
  structure W :
  sig
    include BIT_FLAGS

    (* Report a child that has stopped as well as one that has ended.

       Reading: `Posix.Process.W.untraced/needed-for-stopped`. Without it a
       child that is merely stopped does not end the wait: `waitpid_nh`
       gives `NONE`.

       Implementation: `Posix.Process.W/only-untraced`. It is the only flag
       here; the `WNOHANG` of POSIX is what `waitpid_nh` is, and is added by
       that function itself.

       Pinned by: `Posix.Process.W.untraced/waitpid-without-it` *)
    val untraced : flags
  end

  (* `wait ()` waits for any child to end and is its number and how it ended.

     Raises: `OS.SysErr` if the process has no child. *)
  val wait : unit -> pid * exit_status

  (* `waitpid (arg, flags)` waits for the child that `arg` names and is its number and how it ended.

     Raises: `OS.SysErr` if there is no such child. *)
  val waitpid : waitpid_arg * W.flags list -> pid * exit_status

  (* `waitpid_nh (arg, flags)` is `waitpid` that does not wait: `NONE` when no such child has ended yet.

     Raises: `OS.SysErr` if there is no such child at all. *)
  val waitpid_nh : waitpid_arg * W.flags list -> (pid * exit_status) option

  (* `exit st` ends the process at once with the status `st`.

     Nothing is flushed and no `OS.Process.atExit` action runs; it is the
     `_exit` of POSIX. *)
  val exit : Word8.word -> 'a

  (* Which process `kill` is to signal. *)
  datatype killpid_arg
    = K_PROC of pid    (* that one process *)
    | K_SAME_GROUP     (* every process in this one's group *)
    | K_GROUP of pid   (* every process in that group *)

  (* `kill (arg, s)` sends the signal `s` to the process or the group that `arg` names.

     Raises: `OS.SysErr` if there is no such process, or the signal may not
     be sent to it. *)
  val kill : killpid_arg * signal -> unit

  (* `alarm t` asks for `Posix.Signal.alrm` in `t`, and is the time left of the alarm that was set before.

     Reading: `Posix.Process.alarm/zero-cancels`. A time of zero asks for no
     alarm, as POSIX has it, so it cancels the outstanding one and still
     reports the time that was left of it.

     Pinned by: `Posix.Process.alarm/*` *)
  val alarm : Time.time -> Time.time

  (* `pause ()` waits until a signal arrives. *)
  val pause : unit -> unit

  (* `sleep t` waits for the time `t` and is the time left of it.

     Reading: `Posix.Process.sleep/time-left`. The page does not say what the
     result is; it is POSIX's "time left", which is zero when the wait ran
     out and the rest when a signal cut it short.

     Pinned by: `Posix.Process.sleep/*` *)
  val sleep : Time.time -> Time.time
end
