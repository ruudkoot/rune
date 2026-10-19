structure Benchmark =
struct
  val name = "knights-strict"
  structure Program = BenchKnightsFn (BenchStrict)
  val run = Program.run
end
