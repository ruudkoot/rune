structure Benchmark =
struct
  val name = "knights-array-strict"
  structure Program = BenchKnightsArrayFn (BenchStrict)
  val run = Program.run
end
