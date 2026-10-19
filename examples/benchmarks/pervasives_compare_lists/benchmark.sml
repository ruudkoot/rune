structure Benchmark =
struct
  val name = "pervasives_compare_lists"
  val run = BenchStdlibPrimitives.runComparison name
end
