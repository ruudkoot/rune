structure Benchmark =
struct
  val name = "rec_seq_fib"
  fun run [iterations,size] =
    let
      val repetitions = BenchInput.between (1,4) (BenchInput.integer iterations)
      val n = BenchInput.between (0,40) (BenchInput.integer size)
    in
      IntInf.toString (BenchInput.repeat repetitions (fn () => BenchFib.fib n))
    end
    | run _ = raise Fail "rec_seq_fib expects repetitions size"
end
