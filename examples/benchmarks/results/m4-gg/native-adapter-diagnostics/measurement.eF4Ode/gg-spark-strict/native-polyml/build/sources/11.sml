structure Benchmark =
struct
  val name = "gg-spark-strict"
  structure Driver = BenchGGDriverFn (BenchStrict)
  val run = Driver.run "spark"
end
