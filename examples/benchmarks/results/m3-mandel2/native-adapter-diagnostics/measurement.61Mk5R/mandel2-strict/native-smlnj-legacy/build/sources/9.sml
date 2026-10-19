structure Benchmark =
struct
  val name = "mandel2-strict"
  structure Kernel = BenchMandelTwoFn (structure D = BenchStrict structure P = BenchMandelTwoPoint)
  structure Driver = BenchMandelTwoDriverFn (Kernel)
  val run = Driver.run
end
