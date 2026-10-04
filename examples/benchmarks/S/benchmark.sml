structure Benchmark =
struct
  val name = "S"
  fun run [size] =
    let val n = BenchInput.between(0,10000000)(BenchInput.integer size)
        val (result,state) = BenchStockState.run n
        val _ = case result of () => ()
    in "()" end
    | run _ = raise Fail "S expects deterministic work count"
end
