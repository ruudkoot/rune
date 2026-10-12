(* Programs started as children that a runner of tests supervises
   (docs/plans/unit-testing.md, M2): in a directory of their own, in a
   process group (a job on Windows) that can be ended as one, under limits,
   with the signals at their default actions, and waited for with what they
   cost.

   `Unix` and `Posix.Process` start and reap programs too. This adds what a
   runner needs and they lack: the directory, the group, the limits and the
   signals at the start, and the processor time and the memory at the end.

   This signature is Rune's own. On Windows a job has limits of memory and of
   processor time only, a signal's action is always the default, and ending
   a group ends its job.

   Area: The runtime

   Status: extension *)
signature SUBPROCESS =
sig
  (* A child's process: its number, as the system gives it.

     A descriptor is given by its number too (`Posix.FileSys.fdToWord`):
     `Posix`'s types are its own, and this structure is not part of it. *)
  type pid = int

  (* Limits on a child, each `NONE` for none.

     They are the bytes of address space it may hold, the seconds of
     processor time it may take, the bytes of a file it may write (it gets
     SIGXFSZ beyond them), and the bytes of a core dump (0 for none). *)
  type limits = {addressSpace : int option, cpuTime : int option, fileSize : int option, core : int option}

  (* No limits beyond this program's own.

     Example: `#addressSpace unlimited = NONE` *)
  val unlimited : limits

  (* How a child ended, and what it cost: its user and system processor
     time, and the most memory it held resident, in kilobytes (0 where the
     system does not say). *)
  type ended = {pid : pid, status : Posix.Process.exit_status, user : Time.time,
                system : Time.time, peakResident : int}

  (* `spawn {program, args, env, search, dir, stdin, stdout, stderr, group, limits}`
     starts `program` as a child, and is its process.

     `args` are its arguments, its name first, as `Posix.Process.exec` takes
     them; `env` its environment (`NONE`: this program's); `search` looks
     for `program` on `PATH`; `dir` is the directory it starts in (`NONE`:
     this program's); the three descriptors, by number, become its standard
     input, output and error (`NONE`: this program's own); `group` puts it in a
     process group of its own, which `kill` ends as one. Its signals start
     at their default actions. A program that cannot be run is, on POSIX, a
     child that exits with 126.

     Raises: `OS.SysErr` when the child cannot be started. *)
  val spawn : {program : string, args : string list, env : string list option, search : bool,
               dir : string option, stdin : int option, stdout : int option, stderr : int option,
               group : bool, limits : limits} -> pid

  (* `wait pid` waits for the child `pid` to end (`NONE`: any child), and
     is how it ended and what it cost.

     Raises: `OS.SysErr` when there is no such child. *)
  val wait : pid option -> ended

  (* `poll pid` is `wait pid` if the child has ended, and `NONE` at once if
     it has not.

     Raises: `OS.SysErr` when there is no such child. *)
  val poll : pid option -> ended option

  (* `kill (pid, s)` sends the signal `s` to the process group of the child
     `pid`, which `spawn` made with `group`.

     The group is the child and every process it started. On Windows it ends
     the child's job.

     Raises: `OS.SysErr` when there is no such group. *)
  val kill : pid * Posix.Signal.signal -> unit
end
