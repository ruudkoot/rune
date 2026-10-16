structure Benchmark =
struct
  val name = "scs-lazy"
  val run = BenchScsCheck.run false
end
