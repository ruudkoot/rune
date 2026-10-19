structure Benchmark =
struct
  val name = "event-lazy"
  structure Program = BenchEventFn (BenchNeed)
  structure Driver = BenchEventDriverFn (Program)
  val run = Driver.run
end
