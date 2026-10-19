structure Benchmark =
struct
  val name = "pic-lazy"
  structure Kernel = BenchPicFn (BenchNeed)
  structure Driver = BenchPicDriverFn (Kernel)
  val run = Driver.run
end
