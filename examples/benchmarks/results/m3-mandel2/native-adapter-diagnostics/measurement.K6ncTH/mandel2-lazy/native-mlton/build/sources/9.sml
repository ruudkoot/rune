structure Benchmark =
struct
  val name = "mandel2-lazy"
  structure Kernel = BenchMandelTwoFn (structure D = BenchNeed structure P = BenchMandelTwoPoint)
  structure Driver = BenchMandelTwoDriverFn (Kernel)
  val run = Driver.run
end
