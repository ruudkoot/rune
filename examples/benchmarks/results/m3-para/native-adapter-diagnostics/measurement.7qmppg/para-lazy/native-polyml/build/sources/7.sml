structure Benchmark =
struct
  val name = "para-lazy"
  structure Kernel = BenchParaFn (BenchNeed)
  structure Driver = BenchParaDriverFn (Kernel)
  val run = Driver.run
end
