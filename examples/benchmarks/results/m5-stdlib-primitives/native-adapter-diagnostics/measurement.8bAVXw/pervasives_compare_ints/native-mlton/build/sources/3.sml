structure Benchmark =
struct
  val name = "pervasives_compare_ints"
  val run = BenchStdlibPrimitives.runComparison name
end
