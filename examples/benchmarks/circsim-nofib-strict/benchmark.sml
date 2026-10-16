structure Benchmark =
struct
  val name = "circsim-nofib-strict"
  structure Kernel = BenchCircsimFn (BenchStrict)
  structure Driver = BenchCircsimDriverFn (Kernel)
  val run = Driver.run true
end
