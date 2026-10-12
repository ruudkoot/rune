(* Running jobs as children (docs/plans/unit-testing.md, D9 and D11): one
   loop that starts what the scheduler admits, reaps what ended, ends what
   ran too long or wrote too much, and sleeps a little when nothing
   happened. There are no threads and no handlers of signals but the
   interrupt, so this loop is the runner.

   A job is a process in a process group of its own (a job on Windows), with
   its standard input from a file and its output and errors to files, which
   a crash leaves on disk; its signals start at their default actions. A
   job that runs past its time is sent TERM, and KILL after a grace period;
   one whose output passes its cap is stopped by its file-size limit and by
   the loop, which looks at the files' sizes. When the job's process has
   ended and its group has not, the rest of the group is killed and the job
   is said to have left processes behind.

   Area: Running tests *)
signature SUPERVISOR =
sig
  (* A command to run: the program and its arguments, its environment and
     directory, the files of its streams, its time and cap, and what it takes.

     The arguments begin with the program's name. `cap` limits the bytes of
     its output and errors, and of any file it writes (0 for none). The
     rest is what the scheduler needs (`Scheduler.job`). *)
  type command = {program : string, args : string list, env : string list, dir : string,
                  stdin : string, stdout : string, stderr : string, timeout : Time.time, cap : int,
                  cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
                  failedLast : bool, deps : int list}

  (* How a command ended: its exit status or signal, ended by the loop, or
     never started.

     The loop ends a command for its time (`TimedOut`) or its output
     (`Capped`). A command is `Cancelled` when a job it waited for did not
     end well, and `Failed` when the system refused to start it. *)
  datatype outcome = Exited of int | Signalled of int | TimedOut | Capped | Cancelled | Failed of string

  (* What a command cost: its times, its memory and its output, and whether
     it left processes behind.

     The wall time is on the monotonic clock; `peakResident` is the most
     memory it held resident, in kilobytes. *)
  type result = {outcome : outcome, wall : Time.time, user : Time.time, system : Time.time,
                 peakResident : int, outputBytes : int, leaked : bool}

  (* `outcomeName oc` is `oc` as a word or two, for a report.

     Example: `outcomeName (Exited 3) = "exit 3"` *)
  val outcomeName : outcome -> string

  (* `run {commands, cpus, memory, finished, tick}` runs `commands` as
     `Scheduler.admit` admits them, and tells `finished` each one's result.

     The machine has `cpus` processors and `memory` megabytes. `tick` is
     called with the number running whenever the loop has nothing to do,
     for a display.

     `finished` says whether the command passed. A command that waits for
     one that did not pass is not started, and is `Cancelled`. An interrupt (`SML90.Interrupt`) kills every
     running group and is raised again. *)
  val run : {commands : command vector, cpus : int, memory : int,
             finished : int * result -> bool, tick : int -> unit} -> unit
end
