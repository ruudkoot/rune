structure Benchmark =
struct
  val name = "boyer2-strict"
  structure Kernel = BenchBoyerTwoFn (BenchStrict)
  structure Driver = BenchBoyerTwoDriverFn (Kernel)
  val run = Driver.run
end
