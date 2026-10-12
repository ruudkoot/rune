(* Which jobs to start (docs/plans/unit-testing.md, D12): a pure function of
   the jobs, what has finished, what runs and what is free, so that it can be
   tested on a simulated clock.

   A job takes CPUs and megabytes of memory while it runs, may hold named
   pools (mutexes: two jobs that name one never overlap), may be exclusive
   (it runs alone), and may wait for other jobs. Its priority is the critical
   path: the longest chain of costs from it to the end of the run, so that
   among jobs with no edges the longest starts first (Graham's LPT). A job
   that failed last time starts before any other. An exclusive job that is
   next lets the running jobs drain, and nothing starts in front of it.

   Area: Running tests *)
signature SCHEDULER =
sig
  (* A job as the scheduler sees it: its cost, what it takes and holds, and
     the jobs it waits for.

     The cost is in seconds, from the history. `deps` are the indices of
     the jobs it waits for; `exclusive` runs it alone. *)
  type job = {cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
              failedLast : bool, deps : int list}

  (* What the machine has free: CPUs and megabytes, and the pools held. *)
  type free = {cpus : int, memory : int, held : string list}

  (* A run's plan: the jobs and their priorities. *)
  type plan

  (* `plan jobs` is the plan of `jobs`, numbered by their places.

     Raises: `Fail` if a job waits for itself, or for one that waits for
     it. *)
  val plan : job vector -> plan

  (* `priority (p, i)` is job `i`'s priority: its cost and the longest chain
     of costs after it, and more than every other for a job that failed
     last time.

     Example: `Real.== (priority (plan (Vector.fromList [{cost = 2.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), 0), 2.0)` *)
  val priority : plan * int -> real

  (* `next (p, {waiting, finished, running, free})` is the jobs among
     `waiting` to start now, the highest priority first.

     A job may start once every job it waits for is in `finished`, when it
     fits what is free, and when no job in `running` holds a pool of its.

     A job that takes more than the machine has starts alone when nothing
     runs, so that no job waits forever. *)
  val next : plan * {waiting : int list, finished : int list, running : int list, free : free} -> int list

  (* `simulate (p, {cpus, memory})` is when each job would start, and the
     makespan, in the schedule `next` makes.

     The machine has `cpus` and `memory`, and each job takes its cost.

     Example: `Real.== (#2 (simulate (plan (Vector.fromList [{cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = []}]), {cpus = 4, memory = 100})), 1.0)` *)
  val simulate : plan * {cpus : int, memory : int} -> real vector * real
end
