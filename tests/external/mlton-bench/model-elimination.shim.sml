(* a deterministic Timer for the count oracle (docs/testing.md). The prover slices its search by CPU
   time, so a slower VM did less work per slice and the --count line moved.
   Here every check advances the clock by 100 us (about one inference in
   the timed run), which makes the run the same on every VM. *)
structure Timer = struct
  val ticks = ref (0 : LargeInt.int)
  type cpu_timer = LargeInt.int
  type real_timer = LargeInt.int
  fun now () = (ticks := !ticks + 100; Time.fromMicroseconds (!ticks))
  fun startCPUTimer () = !ticks
  fun startRealTimer () = !ticks
  fun checkCPUTimer t = let val n = now () in {usr = Time.-(n, Time.fromMicroseconds t), sys = Time.zeroTime} end
  fun checkRealTimer t = Time.-(now (), Time.fromMicroseconds t)
end
