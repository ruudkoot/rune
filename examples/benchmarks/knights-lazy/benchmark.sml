structure Benchmark =
struct
  val name = "knights-lazy"
  structure Program = BenchKnightsFn (BenchNeed)
  val run = Program.run
end
