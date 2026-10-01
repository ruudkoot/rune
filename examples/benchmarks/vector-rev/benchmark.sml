(* MLton b15e2d289c3d701131733665a74e2dd8438410b6, source and changes in PROVENANCE.md.
   Copyright and permission notice retained in LICENSE. *)
structure Benchmark =
struct
  val name = "vector-rev"
  fun reverse v =
    let val n = Vector.length v
    in Vector.tabulate (n, fn i => Vector.sub (v, n - 1 - i)) end
  fun run [size, reps] =
        let val n = BenchInput.between (1, 200000) (BenchInput.integer size)
            val count = BenchInput.between (1, 1001) (BenchInput.integer reps)
            val input = Vector.tabulate (n, fn i => i)
            fun one () =
              let val result = reverse (reverse input)
                  fun loop (i, sum) = if i = n then sum else
                    if Vector.sub (result, i) = i then loop (i + 1, IntInf.+ (sum, IntInf.fromInt i))
                    else raise Fail "vector reversal"
              in loop (0, IntInf.fromInt 0) end
            fun loop (0, sum) = sum | loop (k, sum) = loop (k - 1, IntInf.+ (sum, one ()))
        in IntInf.toString (loop (count, IntInf.fromInt 0)) end
    | run _ = raise Fail "vector-rev expects size repetitions"
end
