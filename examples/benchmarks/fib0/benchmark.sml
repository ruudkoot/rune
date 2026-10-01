structure Benchmark =
struct
  val name="fib0"
  fun fib 0=1 | fib 1=1 | fib n=fib(n-1)+fib(n-2)
  fun run [size,reps] = IntInf.toString(BenchInput.repeat(BenchInput.between(1,1000)(BenchInput.integer reps))
      (fn()=>fib(BenchInput.between(0,40)(BenchInput.integer size))))
  | run _=raise Fail "fib0 expects argument repetitions"
end
