(* MLton source at b15e2d289c3d701131733665a74e2dd8438410b6; notice in LICENSE.
   Input sizes are parameterized; the algorithm is retained. *)
structure Benchmark =
struct
  val name = "fib"
  val fib = BenchFib.fib
  fun run [size, reps] =
        let val n = BenchInput.between (0, 44) (BenchInput.integer size)
            val count = BenchInput.between (1, 10000) (BenchInput.integer reps)
        in IntInf.toString (BenchInput.repeat count (fn () => fib n)) end
    | run _ = raise Fail "fib expects size repetitions"
end
