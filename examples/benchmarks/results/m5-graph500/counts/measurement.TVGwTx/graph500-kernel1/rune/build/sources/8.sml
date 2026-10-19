structure Benchmark =
struct
  val name = "graph500-kernel1"
  val run = BenchGraph500Driver.kernel
end
