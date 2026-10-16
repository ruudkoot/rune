structure Benchmark =
struct
  val name = "circsim-nofib-lazy"
  structure Kernel = BenchCircsimFn (BenchNeed)
  structure Driver = BenchCircsimDriverFn (Kernel)
  val run = Driver.run true
end
