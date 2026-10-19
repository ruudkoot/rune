structure Benchmark =
struct
  val name = "wang-strict"
  structure Kernel = BenchWangFn (BenchStrict)
  structure Driver = BenchWangDriverFn (Kernel)
  val run = Driver.run
end
