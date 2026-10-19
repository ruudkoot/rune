structure Benchmark =
struct
  val name = "stack_push_pop"
  fun run [size] =
    let val n = BenchInput.between(0,200000000)(BenchInput.integer size)
    in IntInf.toString(BenchOcamlStack.pushPopRun n)end
    | run _ = raise Fail "stack_push_pop expects iteration count"
end
