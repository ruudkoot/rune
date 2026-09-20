(* The signals a process may be sent, by name.

   A signal is a number that the system uses to interrupt a process:
   `Posix.Process.kill` sends one, `Unix.kill` sends one to a child, and
   `Posix.Process.fromStatus` reports the one that ended a process. The names
   below are the signals POSIX prescribes; `fromWord` reaches the others.

   Nothing here installs a handler: this signature names signals, it does not
   catch them.

   Area: The operating system

   Status: optional

   See also: `POSIX_PROCESS`, `UNIX`, `POSIX`

   Implementation: `Posix.Signal/numbers-are-the-systems`. A signal is the
   number the system gives it, which differs from system to system; the suite
   checks each name against what the shell's `kill -l` calls that number.
   Signals that would dump core, stop the process or be ignored by the runner
   are checked by number only and never sent.

   Pinned by: `Posix.Signal.term/kill-l`, `Posix.Signal.toWord/distinct` *)
signature POSIX_SIGNAL =
sig
  (* The type of a signal.

     Two are equal when they are the same signal. *)
  eqtype signal

  (* `toWord s` is the number the system gives `s`.

     Example: `toWord kill = 0w9` *)
  val toWord : signal -> SysWord.word

  (* `fromWord w` is the signal numbered `w`, which need not be one named here.

     Example: `fromWord 0w15 = term` *)
  val fromWord : SysWord.word -> signal

  (* ---- The signals POSIX names ---- *)

  (* Abort: the process ended itself, as `abort` does. *)
  val abrt : signal

  (* The alarm set by `Posix.Process.alarm` has gone off. *)
  val alrm : signal

  (* A memory access the hardware refused. *)
  val bus : signal

  (* An arithmetic fault, such as a division by zero. *)
  val fpe : signal

  (* The terminal the process was attached to has gone. *)
  val hup : signal

  (* The processor met an instruction it cannot run. *)
  val ill : signal

  (* The interrupt character was typed, usually control-C. *)
  val int : signal

  (* End the process; it cannot be caught, blocked or ignored. *)
  val kill : signal

  (* A pipe or a socket was written that nobody reads.

     See also: `POSIX_ERROR` *)
  val pipe : signal

  (* The quit character was typed, usually control-backslash. *)
  val quit : signal

  (* The process touched memory that is not its own. *)
  val segv : signal

  (* Ask the process to end; the polite one, which may be caught. *)
  val term : signal

  (* A signal with no meaning of its own, for a program to use. *)
  val usr1 : signal

  (* A second signal with no meaning of its own. *)
  val usr2 : signal

  (* A child has stopped or ended. *)
  val chld : signal

  (* Carry on after having been stopped. *)
  val cont : signal

  (* Stop the process; it cannot be caught, blocked or ignored. *)
  val stop : signal

  (* Stop the process, from the terminal; usually control-Z. *)
  val tstp : signal

  (* A background process tried to read from the terminal. *)
  val ttin : signal

  (* A background process tried to write to the terminal. *)
  val ttou : signal
end
