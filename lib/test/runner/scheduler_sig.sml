(* Which jobs to start (docs/plans/unit-testing.md, D12): the jobs of a run,
   what has ended and what is free decide it, so that it can be tested on a
   simulated clock.

   A job takes CPUs and megabytes of memory while it runs, may hold named
   pools (mutexes: two jobs that name one never overlap), may be exclusive
   (it runs alone), and may wait for other jobs. Its priority is the critical
   path: the longest chain of costs from it to the end of the run, so that
   among jobs with no edges the longest starts first (Graham's LPT). A job
   that failed last time starts before any other. An exclusive job that is
   next lets the running jobs drain, and nothing starts in front of it.

   A run's state is kept as it goes, so that a run of thousands of jobs costs
   little at each start and end: the jobs each waits for are counted down,
   and the jobs that may start are kept in the order of their priorities.

   Area: Running tests *)
signature SCHEDULER =
sig
  (* A job as the scheduler sees it: its cost, what it takes and holds, and
     the jobs it waits for.

     The cost is in seconds, from the history. `deps` are the indices of
     the jobs it waits for; `exclusive` runs it alone. *)
  type job = {cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
              failedLast : bool, deps : int list}

  (* A run's plan: the jobs and their priorities. *)
  type plan

  (* `plan jobs` is the plan of `jobs`, numbered by their places.

     Raises: `Fail` if a job waits for itself, or for one that waits for
     it, or for no job. *)
  val plan : job vector -> plan

  (* `priority (p, i)` is job `i`'s priority: its cost and the longest chain
     of costs after it, and more than every other for a job that failed
     last time.

     Example: `Real.== (priority (plan (Vector.fromList [{cost = 2.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), 0), 2.0)` *)
  val priority : plan * int -> real

  (* A run under way: which jobs wait, run and have ended, and what the
     running ones take. *)
  type state

  (* `start p` is the state of a run of `p` before any job has started. *)
  val start : plan -> state

  (* `admit (s, {cpus, memory})` is the jobs to start now, the highest
     priority first, on a machine of `cpus` and `memory`; they are running
     from then on.

     A job may start once every job it waits for has ended well, when it
     fits what the running jobs leave free, and when no running job holds a
     pool of its. A job that takes more than the machine has starts alone
     when nothing runs, so that no job waits forever. *)
  val admit : state * {cpus : int, memory : int} -> int list

  (* `ended (s, i, ok)` records that job `i` ended, well when `ok`, and is
     the jobs that will now never start.

     Those are the jobs that wait, directly or not, for a job that did not
     end well. *)
  val ended : state * int * bool -> int list

  (* `retry (s, i)` puts the running job `i` back among those that may
     start, as if it had not run. *)
  val retry : state * int -> unit

  (* `finished s` says whether no job waits or runs. *)
  val finished : state -> bool

  (* `simulate (p, {cpus, memory})` is when each job would start, and the
     makespan, in the schedule `admit` makes.

     The machine has `cpus` and `memory`, and each job takes its cost.

     Example: `Real.== (#2 (simulate (plan (Vector.fromList [{cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), {cpus = 4, memory = 100})), 1.0)` *)
  val simulate : plan * {cpus : int, memory : int} -> real vector * real
end
