structure Benchmark =
struct
  val name = "last-piece-lazy"
  structure Kernel = BenchLastPieceFn (BenchNeed)
  structure Driver = BenchLastPieceDriverFn (Kernel)
  val run = Driver.run
end
