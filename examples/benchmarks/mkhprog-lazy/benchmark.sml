structure Benchmark =
struct
  val name = "mkhprog-lazy"
  structure Kernel = BenchMkhprogFn (BenchNeed)
  structure Driver = BenchMkhprogDriverFn (Kernel)
  val run = Driver.run
end
