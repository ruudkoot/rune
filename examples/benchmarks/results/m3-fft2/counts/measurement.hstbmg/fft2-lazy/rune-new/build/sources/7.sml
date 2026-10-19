structure Benchmark =
struct
  val name = "fft2-lazy"
  structure Kernel = BenchFFT2Fn (BenchNeed)
  structure Driver = BenchFFT2DriverFn (Kernel)
  val run = Driver.run
end
