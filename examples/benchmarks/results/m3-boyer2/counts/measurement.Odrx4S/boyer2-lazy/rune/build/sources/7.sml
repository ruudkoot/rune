structure Benchmark =
struct
  val name = "boyer2-lazy"
  structure Kernel = BenchBoyerTwoFn (BenchNeed)
  structure Driver = BenchBoyerTwoDriverFn (Kernel)
  val run = Driver.run
end
