structure Benchmark =
struct
  val name = "gg-spark-lazy"
  structure Driver = BenchGGDriverFn (BenchNeed)
  val run = Driver.run "spark"
end
