structure Benchmark =
struct
  val name = "last-piece-strict"
  structure Kernel = BenchLastPieceFn (BenchStrict)
  structure Driver = BenchLastPieceDriverFn (Kernel)
  val run = Driver.run
end
