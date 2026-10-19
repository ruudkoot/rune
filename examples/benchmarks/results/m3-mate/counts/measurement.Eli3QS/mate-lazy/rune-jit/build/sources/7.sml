structure Benchmark =
struct
  val name = "mate-lazy"
  structure Program = BenchMateFn (struct val eagerMoves = false end)
  val run = Program.run
end
