structure Benchmark =
struct
  val name = "multiplier-count-strict"
  structure Program = BenchMultiplierFn (struct val eagerBinary = true end)
  structure Driver = BenchMultiplierDriverFn (Program)
  val run = Driver.runCount
end
