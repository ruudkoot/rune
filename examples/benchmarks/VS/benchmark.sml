structure Benchmark =
struct
  val name = "VS"
  fun run [size] =
    let val n = BenchInput.between(0,10000000)(BenchInput.integer size)
        val (result,state) = BenchVanState.run n
        val actual = state
        val _ = if actual=n then () else raise Fail "state result differs"
        val _ = case result of () => ()
    in "():" ^ Int.toString actual end
    | run _ = raise Fail "VS expects deterministic work count"
end
