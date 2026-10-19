structure Benchmark =
struct
  val name = "exact-reals-lazy"
  structure Kernel = BenchExactRealsFn (BenchNeed)
  structure Driver = BenchExactRealsDriverFn (Kernel)
  val run = Driver.run
end
