structure Benchmark =
struct
  val name = "gg-pool-lazy"
  structure Driver = BenchGGDriverFn (BenchNeed)
  val run = Driver.run "pool"
end
