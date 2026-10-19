structure Benchmark =
struct
  val name = "fft-nofib-strict"
  structure Kernel = BenchHartelFftFn (BenchStrict)
  structure Driver = BenchHartelFftDriverFn (Kernel)
  val run = Driver.run
end
