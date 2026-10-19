structure Benchmark =
struct
  val name = "atom-lazy"
  structure Kernel = BenchAtomFn (BenchNeed)
  structure Driver = BenchAtomDriverFn (Kernel)
  val run = Driver.run
end
