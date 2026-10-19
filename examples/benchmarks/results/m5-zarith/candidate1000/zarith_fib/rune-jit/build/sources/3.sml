structure Benchmark =
struct
  val name="zarith_fib"
  structure N=BenchZarithBig
  structure Kernel=BenchZarithFibFn(N)
  fun run [argument,reference] =
    let val n=BenchInput.between(0,40)(BenchInput.integer argument)
        fun check value=if N.toString value=reference then () else raise Fail "integer result differs"
        val result=Kernel.fib n
        val _=check result
    in N.toString result end
    | run _=raise Fail "zarith_fib expects argument reference"
end
