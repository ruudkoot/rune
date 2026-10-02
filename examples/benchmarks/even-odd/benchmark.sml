(* MLton source at b15e2d289c3d701131733665a74e2dd8438410b6; notice in LICENSE.
   Input sizes are parameterized; the algorithm is retained. *)
structure Benchmark =
struct
  val name = "even-odd"
  fun even 0 = true | even n = odd (n - 1)
  and odd 0 = false | odd n = even (n - 1)
  fun run [size, reps] =
        let val n = BenchInput.between (0, 500000000) (BenchInput.integer size)
            val count = BenchInput.between (1, 10000) (BenchInput.integer reps)
            fun one () =
              let val e = even n val o' = odd n
              in if e = not o' andalso e = (n mod 2 = 0) then (if e then 1 else 0)
                 else raise Fail "parity" end
        in IntInf.toString (BenchInput.repeat count one) end
    | run _ = raise Fail "even-odd expects size repetitions"
end
