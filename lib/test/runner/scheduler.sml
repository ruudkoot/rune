(* The scheduler: priorities by critical path, admission by CPUs, memory,
   pools and exclusion, and a simulation on a clock of its own. *)
structure Scheduler :> SCHEDULER =
struct
  type job = {cost : real, cpus : int, memory : int, pools : string list, exclusive : bool,
              failedLast : bool, deps : int list}
  (* the jobs, their priorities, who waits for each, and each job's rank:
     its place among all the jobs by priority, highest first, ties by
     number *)
  type plan = {jobs : job vector, prio : real vector, dependents : int list vector, rank : int vector}

  (* a priority above every chain, for the jobs that failed last time *)
  val failedBonus = 1.0e12

  (* merge sort, by a strict order *)
  fun sort less xs =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if less (y, x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split xs in merge (go a, go b) end
    in go xs end

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
      fun ahead (a, b) =
        let val pa = Vector.sub (prio, a) and pb = Vector.sub (prio, b)
        in pa > pb orelse (Real.== (pa, pb) andalso a < b) end
      val order = sort ahead (List.tabulate (n, fn i => i))
      val rank = Array.array (n, 0)
      val _ = List.foldl (fn (i, k) => (Array.update (rank, i, k); k + 1)) 0 order
    in
      {jobs = jobs, prio = prio, dependents = Array.vector dependents, rank = Array.vector rank}
    end

  fun priority ({prio, ...} : plan, i) = Vector.sub (prio, i)

  (* the status of a job *)
  datatype status = Blocked | Ready | Running | Ended

  type state = {plan : plan, status : status array, missing : int array,
                ready : int list ref,          (* by rank *)
                cpus : int ref, memory : int ref, held : string list ref,
                running : int ref, exclusive : bool ref, unfinished : int ref}

  fun start (p as {jobs, rank, ...} : plan) : state =
    let
      val n = Vector.length jobs
      val missing = Array.tabulate (n, fn i => length (#deps (Vector.sub (jobs, i))))
      val status = Array.tabulate (n, fn i => if Array.sub (missing, i) = 0 then Ready else Blocked)
      val ready = sort (fn (a, b) => Vector.sub (rank, a) < Vector.sub (rank, b))
                       (List.filter (fn i => Array.sub (status, i) = Ready) (List.tabulate (n, fn i => i)))
    in
      {plan = p, status = status, missing = missing, ready = ref ready, cpus = ref 0, memory = ref 0,
       held = ref [], running = ref 0, exclusive = ref false, unfinished = ref n}
    end

  fun member (x, xs) = List.exists (fn y => y = x) xs
  fun removeOne (_, []) = []
    | removeOne (x, y :: ys) = if x = y then ys else y :: removeOne (x, ys)

  fun admit (s as {plan = {jobs, ...}, status, ready, cpus = used, memory = usedMem, held, running, exclusive, ...} : state,
             {cpus, memory}) =
    let
      fun take i =
        let val {cpus = c, memory = m, pools, exclusive = x, ...} = Vector.sub (jobs, i)
        in
          Array.update (status, i, Running);
          used := !used + c; usedMem := !usedMem + m; held := pools @ !held;
          running := !running + 1; if x then exclusive := true else ()
        end
      (* the ready jobs by rank; what starts, and what stays ready *)
      fun go ([], started, kept) = (rev started, rev kept)
        | go (all as i :: rest, started, kept) =
            let
              val {cpus = c, memory = m, pools, exclusive = x, ...} = Vector.sub (jobs, i)
              val nothingRuns = !running = 0
            in
              if x then
                (* next and exclusive: it starts when nothing runs, and holds back the rest *)
                if nothingRuns then (take i; (rev (i :: started), rev kept @ rest)) else (rev started, rev kept @ all)
              else if List.exists (fn q => member (q, !held)) pools then go (rest, started, i :: kept)
              else if (!used + c <= cpus andalso !usedMem + m <= memory) orelse nothingRuns then
                (take i; go (rest, i :: started, kept))
              else if !used >= cpus then (rev started, rev kept @ all)   (* nothing more fits *)
              else go (rest, started, i :: kept)
            end
    in
      if !exclusive then []
      else let val (started, kept) = go (!ready, [], []) in ready := kept; started end
    end

  fun ended ({plan = {jobs, dependents, rank, ...}, status, missing, ready, cpus, memory, held, running, exclusive,
              unfinished} : state, i, ok) =
    let
      val {cpus = c, memory = m, pools, exclusive = x, ...} = Vector.sub (jobs, i)
      val wasRunning = Array.sub (status, i) = Running
      fun insert (j, []) = [j]
        | insert (j, k :: ks) = if Vector.sub (rank, j) < Vector.sub (rank, k) then j :: k :: ks else k :: insert (j, ks)
      (* the jobs that wait for j, and those that wait for them, never start *)
      fun cancel (j, acc) =
        List.foldl (fn (d, acc) =>
                      case Array.sub (status, d) of
                        Ended => acc
                      | Running => acc
                      | _ => (Array.update (status, d, Ended); unfinished := !unfinished - 1;
                              ready := List.filter (fn k => k <> d) (!ready); cancel (d, d :: acc)))
                   acc (Vector.sub (dependents, j))
    in
      if Array.sub (status, i) = Ended then []
      else
        (if wasRunning then
           (cpus := !cpus - c; memory := !memory - m; held := List.foldl removeOne (!held) pools;
            running := !running - 1; if x then exclusive := false else ())
         else ready := List.filter (fn k => k <> i) (!ready);
         Array.update (status, i, Ended);
         unfinished := !unfinished - 1;
         if ok then
           (List.app (fn d =>
                        (Array.update (missing, d, Array.sub (missing, d) - 1);
                         if Array.sub (missing, d) = 0 andalso Array.sub (status, d) = Blocked
                         then (Array.update (status, d, Ready); ready := insert (d, !ready)) else ()))
                     (Vector.sub (dependents, i));
            [])
         else rev (cancel (i, [])))
    end

  fun retry ({plan = {jobs, rank, ...}, status, ready, cpus, memory, held, running, exclusive, ...} : state, i) =
    if Array.sub (status, i) <> Running then ()
    else
      let
        val {cpus = c, memory = m, pools, exclusive = x, ...} = Vector.sub (jobs, i)
        fun insert (j, []) = [j]
          | insert (j, k :: ks) = if Vector.sub (rank, j) < Vector.sub (rank, k) then j :: k :: ks else k :: insert (j, ks)
      in
        cpus := !cpus - c; memory := !memory - m; held := List.foldl removeOne (!held) pools;
        running := !running - 1; if x then exclusive := false else ();
        Array.update (status, i, Ready); ready := insert (i, !ready)
      end

  fun finished ({unfinished, ...} : state) = !unfinished = 0

  fun simulate (p as {jobs, ...} : plan, machine) =
    let
      val n = Vector.length jobs
      val starts = Array.array (n, 0.0)
      val s = start p
      (* the running jobs, with when they end *)
      fun step (clock, running) =
        let
          val starting = admit (s, machine)
          val () = List.app (fn i => Array.update (starts, i, clock)) starting
          val running = running @ List.map (fn i => (i, clock + #cost (Vector.sub (jobs, i)))) starting
        in
          case running of
            [] => if finished s then clock else raise Fail "jobs that can never start"
          | _ =>
              let
                val soonest = List.foldl (fn ((_, e), m) => Real.min (e, m)) Real.posInf running
                val (done, still) = List.partition (fn (_, e) => Real.<= (e, soonest)) running
              in
                List.app (fn (i, _) => ignore (ended (s, i, true))) done;
                step (soonest, still)
              end
        end
      val makespan = step (0.0, [])
    in
      (Array.vector starts, makespan)
    end
end
