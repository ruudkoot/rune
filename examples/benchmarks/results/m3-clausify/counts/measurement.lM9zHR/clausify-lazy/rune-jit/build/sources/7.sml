structure Benchmark =
struct
  val name = "clausify-lazy"
  structure Kernel = BenchClausifyFn(BenchNeed)
  structure Driver = BenchClausifyDriverFn(Kernel)
  val run = Driver.run
end
