structure Benchmark =
struct
  val name = "prolog-tree-lazy"
  structure Kernel = BenchPrologFn (BenchNeed)
  structure Driver = BenchPrologDriverFn (Kernel)
  val run = Driver.run true
end
