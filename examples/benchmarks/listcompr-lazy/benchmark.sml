structure Benchmark =
struct
  val name = "listcompr-lazy"
  structure Kernel = BenchHartelComprFn (BenchNeed)
  structure Driver = BenchHartelComprDriverFn (Kernel)
  val run = Driver.run false
end
