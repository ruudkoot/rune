structure Benchmark =
struct
  val name = "event-strict"
  structure Program = BenchEventFn (BenchStrict)
  structure Driver = BenchEventDriverFn (Program)
  val run = Driver.run
end
