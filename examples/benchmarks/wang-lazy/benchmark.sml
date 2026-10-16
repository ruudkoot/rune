structure Benchmark =
struct
  val name = "wang-lazy"
  structure Kernel = BenchWangFn (BenchNeed)
  structure Driver = BenchWangDriverFn (Kernel)
  val run = Driver.run
end
