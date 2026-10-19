structure Benchmark =
struct
  val name = "boyer-nofib-lazy"
  structure Kernel = BenchTypedBoyerFn (BenchNeed)
  structure Driver = BenchTypedBoyerDriverFn (Kernel)
  val run = Driver.run
end
