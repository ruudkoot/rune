structure Benchmark =
struct
  val name = "knights-array-lazy"
  structure Program = BenchKnightsArrayFn (BenchNeed)
  val run = Program.run
end
