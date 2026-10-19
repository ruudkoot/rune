structure Benchmark =
struct
  val name = "array_iter"
  val run = BenchStdlibPrimitives.runArray name
end
