structure Benchmark =
struct
  val name="kitfib35"
  fun fib n=if n<1 then 1 else fib(n-1)+fib(n-2)
  fun run [size,reps] = IntInf.toString(BenchInput.repeat(BenchInput.between(1,1000)(BenchInput.integer reps))
      (fn()=>fib(BenchInput.between(0,40)(BenchInput.integer size))))
  | run _=raise Fail "kitfib35 expects argument repetitions"
end
