(* MLton b15e2d289c3d701131733665a74e2dd8438410b6, source and changes in PROVENANCE.md.
   Copyright and permission notice retained in LICENSE. *)
structure Benchmark =
struct
  val name = "vector32-concat"
  fun run [size, reps] =
        let val n = BenchInput.between (1, 20000) (BenchInput.integer size)
            val count = BenchInput.between (1, 10001) (BenchInput.integer reps)
            val input = Vector.tabulate (n, Int32.fromInt)
            val expected = Int32.fromInt (n * (n - 1))
            fun one () =
              let val result = Vector.concat [input, input]
                  val sum = Vector.foldl Int32.+ (Int32.fromInt 0) result
              in if sum = expected andalso Vector.length result = 2 * n then sum
                 else raise Fail "vector concatenation" end
            fun loop (0, sum) = sum
              | loop (k, sum) = loop (k - 1, IntInf.+ (sum, IntInf.fromLarge (Int32.toLarge (one ()))))
        in IntInf.toString (loop (count, IntInf.fromInt 0)) end
    | run _ = raise Fail "vector concatenation expects size repetitions"
end
