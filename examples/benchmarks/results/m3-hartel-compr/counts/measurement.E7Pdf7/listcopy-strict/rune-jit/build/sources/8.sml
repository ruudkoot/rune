structure Benchmark =
struct
  val name = "listcopy-strict"
  structure Kernel = BenchHartelComprFn (BenchStrict)
  structure Driver = BenchHartelComprDriverFn (Kernel)
  val run = Driver.run true
end
