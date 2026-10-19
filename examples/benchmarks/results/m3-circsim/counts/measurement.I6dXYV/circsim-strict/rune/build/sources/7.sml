structure Benchmark =
struct
  val name = "circsim-strict"
  structure Kernel = BenchCircsimFn (BenchStrict)
  structure Driver = BenchCircsimDriverFn (Kernel)
  val run = Driver.run false
end
