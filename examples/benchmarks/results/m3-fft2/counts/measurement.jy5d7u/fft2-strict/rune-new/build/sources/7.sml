structure Benchmark =
struct
  val name = "fft2-strict"
  structure Kernel = BenchFFT2Fn (BenchStrict)
  structure Driver = BenchFFT2DriverFn (Kernel)
  val run = Driver.run
end
