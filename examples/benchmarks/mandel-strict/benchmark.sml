structure Benchmark =
struct
  val name = "mandel-strict"
  structure Kernel = struct
    type pixels = (int * int * int) list
    val make = BenchMandelDouble.makeStrict false
    val app = BenchMandelDouble.appStrict
  end
  structure Driver = BenchMandelDriverFn (Kernel)
  val run = Driver.run
end
