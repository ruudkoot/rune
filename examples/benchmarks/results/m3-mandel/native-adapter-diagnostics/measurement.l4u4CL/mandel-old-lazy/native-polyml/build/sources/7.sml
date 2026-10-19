structure Benchmark =
struct
  val name = "mandel-old-lazy"
  structure Kernel = struct
    type pixels = (int * int * int) BenchStream.stream
    val make = BenchMandelDouble.makeLazy true
    val app = BenchMandelDouble.appLazy
  end
  structure Driver = BenchMandelDriverFn (Kernel)
  val run = Driver.run
end
