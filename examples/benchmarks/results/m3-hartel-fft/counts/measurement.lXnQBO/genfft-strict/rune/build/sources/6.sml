structure Benchmark =
struct
  val name = "genfft-strict"
  structure Kernel = BenchHartelGenFftFn (BenchStrict)
  structure Driver = BenchHartelGenFftDriverFn (Kernel)
  val run = Driver.run
end
