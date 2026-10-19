structure Benchmark =
struct
  val name = "minimax-lazy"
  structure Kernel = BenchMinimaxFn (BenchNeed)
  structure Driver = BenchMinimaxDriverFn (Kernel)
  val run = Driver.run
end
