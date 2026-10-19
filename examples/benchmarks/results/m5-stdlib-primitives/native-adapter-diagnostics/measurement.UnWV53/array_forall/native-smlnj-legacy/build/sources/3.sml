structure Benchmark =
struct
  val name = "array_forall"
  val run = BenchStdlibPrimitives.runArray name
end
