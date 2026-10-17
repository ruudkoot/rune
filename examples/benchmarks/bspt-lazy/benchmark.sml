structure Benchmark =
struct
  val name = "bspt-lazy"
  structure Program = BenchBSPTProgramFn (BenchNeed)
  structure Driver = BenchBSPTDriverFn (Program)
  val run = Driver.run
end
