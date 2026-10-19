structure Benchmark =
struct
  val name = "mandel-old-strict"
  structure Kernel = struct
    type pixels = (int * int * int) list
    val make = BenchMandelDouble.makeStrict true
    val app = BenchMandelDouble.appStrict
  end
  structure Driver = BenchMandelDriverFn (Kernel)
  val run = Driver.run
end
