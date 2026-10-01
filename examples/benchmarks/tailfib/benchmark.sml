(* MLton source at b15e2d289c3d701131733665a74e2dd8438410b6; notice in LICENSE.
   Input sizes are parameterized; the algorithm is retained. *)
structure Benchmark =
struct
  val name = "tailfib"
  fun fib' (0, a, b) = a | fib' (n, a, b) = fib' (n - 1, a + b, a)
  fun fib n = fib' (n, 0, 1)
  fun run [size, reps] =
        let val n = BenchInput.between (0, 44) (BenchInput.integer size)
            val count = BenchInput.between (1, 1000000) (BenchInput.integer reps)
        in IntInf.toString (BenchInput.repeat count (fn () => fib n)) end
    | run _ = raise Fail "tailfib expects size repetitions"
end
