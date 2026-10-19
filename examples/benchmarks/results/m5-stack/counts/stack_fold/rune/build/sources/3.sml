structure Benchmark =
struct
  val name = "stack_fold"
  fun run [size] =
    let val n = BenchInput.between(0,5000000)(BenchInput.integer size)
    in IntInf.toString(BenchOcamlStack.foldRun n)end
    | run _ = raise Fail "stack_fold expects iteration count"
end
