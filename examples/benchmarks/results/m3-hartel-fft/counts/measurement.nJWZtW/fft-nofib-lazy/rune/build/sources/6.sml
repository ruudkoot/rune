structure Benchmark =
struct
  val name = "fft-nofib-lazy"
  structure Kernel = BenchHartelFftFn (BenchNeed)
  structure Driver = BenchHartelFftDriverFn (Kernel)
  val run = Driver.run
end
