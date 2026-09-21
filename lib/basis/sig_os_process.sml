(* The process itself: its environment, the commands it runs, and how it
   ends.

   `exit` ends the program the orderly way: the actions given to `atExit` are
   run, the streams are flushed, and only then does the process stop.
   `terminate` stops it at once, without any of that.

   Area: The operating system

   See also: `OS`, `UNIX`, `POSIX_PROCESS`, `TIME` *)
signature OS_PROCESS =
sig
  (* The type of what a program ends with, and what a command it ran ended with.

     Deviation: `OS.Process.status/is-an-int`. The specification leaves the
     type abstract; in Rune it is `int`, and the type is not made abstract.

     Implementation: `OS.Process.status/of-a-command`. The status of a
     command that `system` ran is its exit code, or 256 plus the number of
     the signal that ended it, which `Posix.Process.fromStatus` decodes. *)
  type status

  (* The status of a program that did what it was meant to do. *)
  val success : status

  (* A status of a program that did not. *)
  val failure : status

  (* `isSuccess st` is `true` when `st` is a status of a program that succeeded.

     Reading: `OS.Process.isSuccess/killed-is-not-success`. A command that a
     signal ended has not succeeded: from `UNIX`, this is true only where
     `Posix.Process.fromStatus` gives `W_EXITED`.

     Pinned by: `OS.Process.isSuccess/killed-by-signal`

     Example: `isSuccess success = true` *)
  val isSuccess : status -> bool

  (* `system cmd` runs `cmd` and is the status it ended with.

     Raises: `OS.SysErr` if the command could not be run at all.

     Reading: `OS.Process.system/a-real-shell`. A shell runs the command, so
     redirection, sequencing and variables work; it runs in the current
     directory, and `system` returns only once the command is done. What the
     process has buffered is neither lost nor written twice by running one.

     Pinned by: `OS.Process.system/*`

     A command that the shell cannot find gives a status that is no success,
     the 127 of the shell; the suite assumes that of every system's shell. *)
  val system : string -> status

  (* `atExit f` asks for `f` to be run when the program ends.

     Implementation: `OS.Process.atExit/how-actions-run`. The actions run in
     the reverse of the order they were given in, at a normal end and at
     `exit` but not at `terminate` and not after an uncaught exception. The
     exception of an action that raises is dropped and the others run, and
     an action that calls `atExit` registers nothing. *)
  val atExit : (unit -> unit) -> unit

  (* `exit st` ends the program with the status `st`, after running the `atExit` actions and flushing the streams.

     Reading: `OS.Process.exit/what-is-flushed`. "Flushes and closes all I/O
     streams" reaches the streams the library still holds output for, over
     writers a program supplied; output to a file is held by the VM, which
     flushes every file itself. *)
  val exit : status -> 'a

  (* `terminate st` ends the program with the status `st` at once.

     No `atExit` action runs and nothing the library holds is flushed. *)
  val terminate : status -> 'a

  (* `getEnv name` is `SOME` of the value of the environment variable `name`, or `NONE`.

     Reading: `OS.Process.getEnv/the-whole-name`. The whole name must match:
     a name that merely begins with one that is set does not, and neither
     does a name with `"=value"` attached. A command run by `system` inherits
     this environment and cannot change it.

     Pinned by: `OS.Process.getEnv/*`

     Example: `getEnv "A_VARIABLE_THAT_NOBODY_SETS" = NONE` *)
  val getEnv : string -> string option

  (* `sleep t` waits for the time `t`, and returns at once when `t` is not positive. *)
  val sleep : Time.time -> unit
end
