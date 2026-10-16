structure Benchmark =
struct
  val name="zarith_tak-natint"
  structure N=BenchZarithNative
  structure Kernel=BenchZarithTakFn(N)
  fun run [argument,reference] =
    let val n=BenchInput.between(0,2500)(BenchInput.integer argument)
        fun check value=if N.toString value=reference then () else raise Fail "integer result differs"
        val result=BenchZarithRepeat.run n Kernel.tak (N.fromInt 18,N.fromInt 12,N.fromInt 6) check
        val _=check result
    in N.toString result end
    | run _=raise Fail "zarith_tak-natint expects argument reference"
end
