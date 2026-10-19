structure Benchmark =
struct
  val name = "multiplier-count-lazy"
  structure Program = BenchMultiplierFn (struct val eagerBinary = false end)
  structure Driver = BenchMultiplierDriverFn (Program)
  val run = Driver.runCount
end
