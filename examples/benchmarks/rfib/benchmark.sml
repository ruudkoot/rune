structure Benchmark=struct
  val name="rfib"
  fun nfib n=if n<=1.0 then 1.0 else nfib(n-1.0)+nfib(n-2.0)+1.0
  fun run[nText]=let val n=BenchInput.between(1,43)(BenchInput.integer nText)
    val _=if Real.precision>=53 then()else raise Fail "requires binary64 precision"
    val result=nfib(Real.fromInt n)
    fun oracle(0,a,b)=2*a-1|oracle(k,a,b)=oracle(k-1,b,a+b)
    val expected=oracle(n+1,0:IntInf.int,1)
    val _=if Real.==(result,Real.fromLargeInt expected)then()else raise Fail "real Fibonacci recurrence"
    in IntInf.toString expected end|run _=raise Fail "rfib expects recurrence argument"end
