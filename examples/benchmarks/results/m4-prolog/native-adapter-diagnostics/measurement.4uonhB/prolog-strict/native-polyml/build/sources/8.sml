structure Benchmark =
struct
  val name = "prolog-strict"
  structure Kernel = BenchPrologFn (BenchStrict)
  structure Driver = BenchPrologDriverFn (Kernel)
  val run = Driver.run false
end
