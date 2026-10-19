structure Benchmark =
struct
  val name = "pervasives_compare_strings"
  val run = BenchStdlibPrimitives.runComparison name
end
