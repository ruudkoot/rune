structure Benchmark =
struct
  val name = "integer-strict"
  structure Kernel = BenchIntegerFn (BenchStrict)
  structure Driver = BenchIntegerDriverFn (Kernel)
  val run = Driver.run
end
