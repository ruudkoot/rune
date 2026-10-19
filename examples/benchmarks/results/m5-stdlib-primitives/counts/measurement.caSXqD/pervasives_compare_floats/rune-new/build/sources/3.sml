structure Benchmark =
struct
  val name = "pervasives_compare_floats"
  val run = BenchStdlibPrimitives.runComparison name
end
