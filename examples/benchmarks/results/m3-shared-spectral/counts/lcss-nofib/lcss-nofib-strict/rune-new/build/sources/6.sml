structure Benchmark =
struct
  structure Kernel = Benchmark
  val name = "lcss-nofib-strict"
  fun run [a,b,c,d,e,f,reference,repetitions] =
    let val times = BenchInput.between (1,500) (BenchInput.integer repetitions)
        val args = [a,b,c,d,e,f,reference]
    in IntInf.toString(BenchInput.repeat times (fn () => BenchInput.integer(Kernel.run args))) end
    | run _ = raise Fail "lcss-nofib expects sequences reference repetitions"
end
