structure Benchmark =
struct
  val name = "gg-strict"
  structure Driver = BenchGGDriverFn (BenchStrict)
  val run = Driver.run "activity"
end
