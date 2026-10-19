structure Benchmark =
struct
  val name = "pretty-strict"
  structure Kernel = BenchPrettyFn (BenchStrict)
  structure Driver = BenchPrettyDriverFn (Kernel)
  val run = Driver.run
end
