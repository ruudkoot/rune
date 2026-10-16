structure Benchmark =
struct
  val name = "circsim-lazy"
  structure Kernel = BenchCircsimFn (BenchNeed)
  structure Driver = BenchCircsimDriverFn (Kernel)
  val run = Driver.run false
end
