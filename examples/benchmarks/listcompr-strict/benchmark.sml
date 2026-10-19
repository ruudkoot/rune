structure Benchmark =
struct
  val name = "listcompr-strict"
  structure Kernel = BenchHartelComprFn (BenchStrict)
  structure Driver = BenchHartelComprDriverFn (Kernel)
  val run = Driver.run false
end
