structure Benchmark =
struct
  val name = "mkhprog-strict"
  structure Kernel = BenchMkhprogFn (BenchStrict)
  structure Driver = BenchMkhprogDriverFn (Kernel)
  val run = Driver.run
end
