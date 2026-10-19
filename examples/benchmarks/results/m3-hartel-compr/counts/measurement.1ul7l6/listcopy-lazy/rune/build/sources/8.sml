structure Benchmark =
struct
  val name = "listcopy-lazy"
  structure Kernel = BenchHartelComprFn (BenchNeed)
  structure Driver = BenchHartelComprDriverFn (Kernel)
  val run = Driver.run true
end
