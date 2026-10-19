structure Benchmark =
struct
  val name = "atom-strict"
  structure Kernel = BenchAtomFn (BenchStrict)
  structure Driver = BenchAtomDriverFn (Kernel)
  val run = Driver.run
end
