structure Benchmark =
struct
  val name = "nbody-sandmark-multicore-numerical"
  val run = BenchManyBodyCheck.run
end
