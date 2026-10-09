(* The message window as a ring: a collector latency workload in the manner of
   the "Pusher" benchmark (James Fisher, "Low latency, large working set, and
   GHC's garbage collector: pick two of three", 2016) and of Gabriel Scherer's
   gc-latency-experiment.

   A window of N live messages, each a byte array of SIZE bytes. Message i is
   made at step i and stored in slot i mod N of an array, where it replaces
   message i - N. So the live data is about N * SIZE bytes, every message
   lives exactly N steps, and every step stores a young message into an old
   array: the case that makes a copier's pauses grow with the live data and
   that a generational collector's barrier sees at every step.

   Arguments: N STEPS SIZE TIME. N + STEPS messages are made; TIME 1 times
   every step and writes the histograms of all steps and of the steady state
   (once the window is full) to the standard error; TIME 0 reads no clock, so
   that what a run allocates and executes (--count) is the same in every run.
   The result is N, STEPS, SIZE and the digest of every message in the order
   made: those evicted, then those left in the window. latency-map computes
   the same digest with a persistent map. *)
structure Benchmark =
struct
  val name = "latency-ring"

  fun window (n, steps, size, timing) =
    let
      val total = n + steps
      val slots = Array.array (n, Word8Array.array (0, 0w0))
      fun push (i, acc) =
        let
          val slot = i mod n
          val acc = if i >= n then Latency.digest (Array.sub (slots, slot), acc) else acc
        in
          Array.update (slots, slot, Latency.message (i, size));
          acc
        end
      val all = Latency.histogram ()
      val steady = Latency.histogram ()
      fun untimed (i, acc) = if i = total then acc else untimed (i + 1, push (i, acc))
      fun timed (i, acc) =
        if i = total then acc
        else
          let
            val t0 = Latency.now ()
            val acc = push (i, acc)
            val d = Latency.since t0
          in
            Latency.add (all, d);
            if i >= n then Latency.add (steady, d) else ();
            timed (i + 1, acc)
          end
      val (acc, wall) =
        if timing then
          let val t0 = Latency.now () val acc = timed (0, 0) in (acc, Latency.since t0) end
        else (untimed (0, 0), 0)
      fun rest (i, acc) =
        if i = total then acc else rest (i + 1, Latency.digest (Array.sub (slots, i mod n), acc))
    in
      (rest (total - n, acc), all, steady, wall)
    end

  fun run [n, steps, size, time] =
        let
          val n = BenchInput.between (1, 100000000) (BenchInput.integer n)
          val steps = BenchInput.between (0, 1000000000) (BenchInput.integer steps)
          val size = BenchInput.between (1, 1048576) (BenchInput.integer size)
          val timing = BenchInput.between (0, 1) (BenchInput.integer time) = 1
          val (sum, all, steady, wall) = window (n, steps, size, timing)
          val result = String.concatWith " " (List.map Int.toString [n, steps, size, sum])
        in
          if timing then
            Latency.report (Latency.line (name ^ " " ^ result ^ " all", all)
                            ^ Latency.line (name ^ " " ^ result ^ " steady", steady)
                            ^ name ^ " " ^ result ^ " wall: " ^ Latency.ms wall ^ " ms\n")
          else ();
          result
        end
    | run _ = raise Fail "latency-ring expects N STEPS SIZE TIME"
end
