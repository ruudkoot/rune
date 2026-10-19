structure Benchmark =
struct
  val name = "bspt-strict"
  structure Program = BenchBSPTProgramFn (BenchStrict)
  structure Driver = BenchBSPTDriverFn (Program)
  val run = Driver.run
end
