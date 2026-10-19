structure Benchmark =
struct
  val name = "mate-strict"
  structure Program = BenchMateFn (struct val eagerMoves = true end)
  val run = Program.run
end
