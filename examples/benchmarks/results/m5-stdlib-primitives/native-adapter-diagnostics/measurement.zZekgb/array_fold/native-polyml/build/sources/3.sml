structure Benchmark =
struct
  val name = "array_fold"
  val run = BenchStdlibPrimitives.runArray name
end
