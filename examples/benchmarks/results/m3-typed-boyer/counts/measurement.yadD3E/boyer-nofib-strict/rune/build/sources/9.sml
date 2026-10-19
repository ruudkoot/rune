structure Benchmark =
struct
  val name = "boyer-nofib-strict"
  structure Kernel = BenchTypedBoyerFn (BenchStrict)
  structure Driver = BenchTypedBoyerDriverFn (Kernel)
  val run = Driver.run
end
