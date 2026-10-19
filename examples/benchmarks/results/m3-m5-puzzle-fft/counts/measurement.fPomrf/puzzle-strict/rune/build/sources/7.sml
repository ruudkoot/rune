structure Benchmark =
struct
  val name="puzzle-strict"
  structure Kernel=BenchPuzzleFn(BenchStrict)
  structure Driver=BenchPuzzleDriverFn(Kernel)
  val run=Driver.run
end
