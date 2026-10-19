structure Benchmark =
struct
  val name = "minimax-strict"
  structure Kernel = BenchMinimaxFn (BenchStrict)
  structure Driver = BenchMinimaxDriverFn (Kernel)
  val run = Driver.run
end
