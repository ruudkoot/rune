(* The scheduler: priorities by critical path, admission by CPUs, memory,
   pools and exclusion, and a simulation on a clock of its own. *)
structure Scheduler :> SCHEDULER =
struct
  type job = {cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
              failedLast : bool, deps : int list}
  type free = {cpus : int, memory : int, held : string list}
  type plan = {jobs : job vector, prio : real vector}

  (* a priority above every chain, for the jobs that failed last time *)
  val failedBonus = 1.0e12

  fun plan (jobs : job vector) : plan =
    let
      val n = Vector.length jobs
      val dependents = Array.array (n, []) : int list array
      val () = Vector.appi (fn (i, {deps, ...} : job) =>
                              List.app (fn d => if d < 0 orelse d >= n then raise Fail "a job waits for no job"
                                                else Array.update (dependents, d, i :: Array.sub (dependents, d))) deps)
                           jobs
      (* the longest chain of costs from a job to the end; ~1.0 not yet known,
         ~2.0 on the way (a cycle) *)
      val memo = Array.array (n, ~1.0)
      fun level i =
        let val m = Array.sub (memo, i)
        in
          if m >= 0.0 then m
          else if m < ~1.5 then raise Fail "jobs wait for one another"
          else
            (Array.update (memo, i, ~2.0);
             let val l = #cost (Vector.sub (jobs, i))
                         + List.foldl (fn (d, best) => Real.max (best, level d)) 0.0 (Array.sub (dependents, i))
             in Array.update (memo, i, l); l end)
        end
      val prio = Vector.tabulate (n, fn i => level i + (if #failedLast (Vector.sub (jobs, i)) then failedBonus else 0.0))
    in
      {jobs = jobs, prio = prio}
    end

  fun priority ({prio, ...} : plan, i) = Vector.sub (prio, i)

  fun member (x, xs) = List.exists (fn y => y = x) xs

  (* the waiting jobs by priority, highest first, ties by number *)
  fun byPriority (p : plan) waiting =
    let
      fun ahead (a, b) = let val pa = priority (p, a) and pb = priority (p, b) in pa > pb orelse (Real.== (pa, pb) andalso a < b) end
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if ahead (x, y) then x :: y :: ys else y :: insert (x, ys)
    in List.foldl insert [] waiting end

  fun next (p as {jobs, ...} : plan, {waiting, finished, running, free = {cpus, memory, held}}) =
    let
      fun ready i = List.all (fn d => member (d, finished)) (#deps (Vector.sub (jobs, i)))
      val candidates = byPriority p (List.filter ready waiting)
      val anyExclusiveRunning = List.exists (fn i => #exclusive (Vector.sub (jobs, i))) running
      fun go ([], _, _, _, _, acc) = rev acc
        | go (i :: rest, freeCpus, freeMem, held, nothingRuns, acc) =
            let
              val {cpus = c, memory = m, pools, exclusive, ...} = Vector.sub (jobs, i)
            in
              if exclusive then
                (* next and exclusive: it starts when nothing runs, and holds back the rest *)
                if nothingRuns then rev (i :: acc) else rev acc
              else if List.exists (fn q => member (q, held)) pools then go (rest, freeCpus, freeMem, held, nothingRuns, acc)
              else if (c <= freeCpus andalso m <= freeMem) orelse nothingRuns then
                go (rest, freeCpus - c, freeMem - m, pools @ held, false, i :: acc)
              else go (rest, freeCpus, freeMem, held, nothingRuns, acc)
            end
    in
      if anyExclusiveRunning then [] else go (candidates, cpus, memory, held, null running, [])
    end

  fun simulate (p as {jobs, ...} : plan, {cpus, memory}) =
    let
      val n = Vector.length jobs
      val starts = Array.array (n, 0.0)
      (* the running jobs, with when they end *)
      fun step (clock, waiting, finished, running) =
        let
          val runningIds = List.map #1 running
          val usedCpus = List.foldl (fn ((i, _), s) => s + #cpus (Vector.sub (jobs, i))) 0 running
          val usedMem = List.foldl (fn ((i, _), s) => s + #memory (Vector.sub (jobs, i))) 0 running
          val held = List.concat (List.map (fn (i, _) => #pools (Vector.sub (jobs, i))) running)
          val starting = next (p, {waiting = waiting, finished = finished, running = runningIds,
                                   free = {cpus = cpus - usedCpus, memory = memory - usedMem, held = held}})
          val () = List.app (fn i => Array.update (starts, i, clock)) starting
          val running = running @ List.map (fn i => (i, clock + #cost (Vector.sub (jobs, i)))) starting
          val waiting = List.filter (fn i => not (member (i, starting))) waiting
        in
          case running of
            [] => if null waiting then clock else raise Fail "jobs that can never start"
          | _ =>
              let
                val soonest = List.foldl (fn ((_, e), m) => Real.min (e, m)) Real.posInf running
                val (done, still) = List.partition (fn (_, e) => Real.<= (e, soonest)) running
              in
                step (soonest, waiting, List.map #1 done @ finished, still)
              end
        end
      val makespan = step (0.0, List.tabulate (n, fn i => i), [], [])
    in
      (Array.vector starts, makespan)
    end
end
