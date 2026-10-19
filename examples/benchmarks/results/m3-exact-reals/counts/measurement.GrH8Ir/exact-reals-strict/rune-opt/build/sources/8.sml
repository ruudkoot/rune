structure Benchmark =
struct
  val name = "exact-reals-strict"
  structure Kernel = BenchExactRealsFn (BenchStrict)
  structure Driver = BenchExactRealsDriverFn (Kernel)
  val run = Driver.run
end
