structure Benchmark =
struct
  val name = "pretty-lazy"
  structure Kernel = BenchPrettyFn (BenchNeed)
  structure Driver = BenchPrettyDriverFn (Kernel)
  val run = Driver.run
end
