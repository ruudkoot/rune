structure Benchmark =
struct
  val name = "integer-lazy"
  structure Kernel = BenchIntegerFn (BenchNeed)
  structure Driver = BenchIntegerDriverFn (Kernel)
  val run = Driver.run
end
