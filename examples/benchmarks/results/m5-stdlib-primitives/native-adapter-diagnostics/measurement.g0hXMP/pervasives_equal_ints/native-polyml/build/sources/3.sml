structure Benchmark =
struct
  val name = "pervasives_equal_ints"
  val run = BenchStdlibPrimitives.runComparison name
end
