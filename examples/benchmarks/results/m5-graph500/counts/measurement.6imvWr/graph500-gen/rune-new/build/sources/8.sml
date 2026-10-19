structure Benchmark =
struct
  val name = "graph500-gen"
  val run = BenchGraph500Driver.generate
end
