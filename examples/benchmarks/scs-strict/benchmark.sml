structure Benchmark =
struct
  val name = "scs-strict"
  val run = BenchScsCheck.run true
end
