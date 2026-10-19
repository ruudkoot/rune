structure Benchmark =
struct
  val name = "genfft-lazy"
  structure Kernel = BenchHartelGenFftFn (BenchNeed)
  structure Driver = BenchHartelGenFftDriverFn (Kernel)
  val run = Driver.run
end
