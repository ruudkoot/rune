structure Benchmark =
struct
  val name = "mandel-lazy"
  structure Kernel = struct
    type pixels = (int * int * int) BenchStream.stream
    val make = BenchMandelDouble.makeLazy false
    val app = BenchMandelDouble.appLazy
  end
  structure Driver = BenchMandelDriverFn (Kernel)
  val run = Driver.run
end
