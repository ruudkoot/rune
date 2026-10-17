structure Benchmark =
struct
  val name = "para-strict"
  structure Kernel = BenchParaFn (BenchStrict)
  structure Driver = BenchParaDriverFn (Kernel)
  val run = Driver.run
end
