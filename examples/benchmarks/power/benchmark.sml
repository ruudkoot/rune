structure Benchmark =
struct
  val name = "power"
  structure Workload = BenchPowerWorkloadFn (BenchPowerInteger)
  fun run [count,reference] =
    let val n = BenchInput.between (1,90) (BenchInput.integer count)
        val file = TextIO.openIn reference
        val expected = TextIO.inputAll file
        val _ = TextIO.closeIn file
        val actual = Workload.output n
        val _ = if actual=expected then () else raise Fail "power series coefficients differ"
    in Int.toString n end
    | run _ = raise Fail "power expects coefficient-count reference"
end
