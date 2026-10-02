structure Kernel = struct

fun fib'(0,a,b) = a
  | fib'(n,a,b) = fib'(n-1,a+b,a)
fun fib n = fib'(n,0,1)


end
structure Benchmark=struct val name="tailfib-mlkit"
fun run [size,reps] = let val n=BenchInput.between(0,44)(BenchInput.integer size) val r=BenchInput.between(1,50000000)(BenchInput.integer reps) in IntInf.toString(BenchInput.repeat r(fn()=>Kernel.fib n)) end | run _=raise Fail "tailfib expects size repetitions"
end
