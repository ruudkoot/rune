structure Benchmark =
struct
  val name="puzzle-lazy"
  structure Kernel=BenchPuzzleFn(BenchNeed)
  structure Driver=BenchPuzzleDriverFn(Kernel)
  val run=Driver.run
end
