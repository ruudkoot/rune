structure Benchmark =
struct
  val name = "gg-lazy"
  structure Driver = BenchGGDriverFn (BenchNeed)
  val run = Driver.run "activity"
end
