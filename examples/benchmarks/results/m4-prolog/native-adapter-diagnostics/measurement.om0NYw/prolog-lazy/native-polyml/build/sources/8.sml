structure Benchmark =
struct
  val name = "prolog-lazy"
  structure Kernel = BenchPrologFn (BenchNeed)
  structure Driver = BenchPrologDriverFn (Kernel)
  val run = Driver.run false
end
