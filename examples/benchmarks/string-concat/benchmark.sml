(* MLton b15e2d289c3d701131733665a74e2dd8438410b6, source and changes in PROVENANCE.md.
   Copyright and permission notice retained in LICENSE. *)
structure Benchmark =
struct
  val name = "string-concat"
  fun run [size, reps] =
        let val n = BenchInput.between (1, 1000000) (BenchInput.integer size)
            val count = BenchInput.between (1, 10001) (BenchInput.integer reps)
            val s = CharVector.tabulate (n, fn i => Char.chr (Char.ord #"A" + i mod 26))
            fun one () = CharVector.foldl (fn (c, sum) => sum + Char.ord c) 0 (String.concat [s, s, s])
        in IntInf.toString (BenchInput.repeat count one) end
    | run _ = raise Fail "string-concat expects length repetitions"
end
