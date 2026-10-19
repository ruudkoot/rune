structure Benchmark =
struct
  val name = "clausify-strict"
  structure Kernel = BenchClausifyFn(BenchStrict)
  structure Driver = BenchClausifyDriverFn(Kernel)
  val run = Driver.run
end
