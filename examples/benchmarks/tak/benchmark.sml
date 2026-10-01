(* Adapted from MLton benchmark/tests/tak.sml at the revision in PROVENANCE.
   MLton copyright and permission notice: LICENSE. Individual author is not
   stated in that source file. The Takeuchi recurrence is unchanged. *)
structure Benchmark =
struct
  val name = "tak"

  fun tak (x, y, z) =
    if not (y < x) then z
    else tak (tak (x - 1, y, z),
              tak (y - 1, z, x),
              tak (z - 1, x, y))

  fun run [sx, sy, sz, repetitions] =
        let
          val x = BenchInput.between (0, 40) (BenchInput.integer sx)
          val y = BenchInput.between (0, 40) (BenchInput.integer sy)
          val z = BenchInput.between (0, 40) (BenchInput.integer sz)
          val count = BenchInput.between (1, 10000) (BenchInput.integer repetitions)
        in
          IntInf.toString (BenchInput.repeat count (fn () => tak (x, y, z)))
        end
    | run _ = raise Fail "tak expects x y z repetitions"
end
