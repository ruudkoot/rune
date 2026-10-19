structure Benchmark =
struct
  val name = "VSM"
  fun run [size] =
    let val n = BenchInput.between(0,10000000)(BenchInput.integer size)
        val (result,state) = BenchVanMtlState.run n
        val actual = BenchLazy.force state
        val _ = if actual=n then () else raise Fail "state result differs"
        val _ = case result of () => ()
    in "():" ^ Int.toString actual end
    | run _ = raise Fail "VSM expects deterministic work count"
end
