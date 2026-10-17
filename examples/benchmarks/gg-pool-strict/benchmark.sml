structure Benchmark =
struct
  val name = "gg-pool-strict"
  structure Driver = BenchGGDriverFn (BenchStrict)
  val run = Driver.run "pool"
end
