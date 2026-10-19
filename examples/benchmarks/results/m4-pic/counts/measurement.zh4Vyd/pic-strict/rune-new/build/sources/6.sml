structure Benchmark =
struct
  val name = "pic-strict"
  structure Kernel = BenchPicFn (BenchStrict)
  structure Driver = BenchPicDriverFn (Kernel)
  val run = Driver.run
end
