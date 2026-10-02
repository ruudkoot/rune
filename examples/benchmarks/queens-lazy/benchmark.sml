structure Benchmark =
struct
  val name = "queens-lazy"
  fun run [size,reps] =
    let val n = BenchInput.between (1,14) (BenchInput.integer size)
        val r = BenchInput.between (1,1000) (BenchInput.integer reps)
    in IntInf.toString (BenchInput.repeat r (fn () => BenchQueens.lazy n)) end
    | run _ = raise Fail "queens-lazy expects board size repetitions"
end
