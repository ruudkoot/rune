structure Benchmark =
struct
  val name = "prolog-tree-strict"
  structure Kernel = BenchPrologFn (BenchStrict)
  structure Driver = BenchPrologDriverFn (Kernel)
  val run = Driver.run true
end
