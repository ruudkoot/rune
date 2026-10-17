structure Benchmark =
struct
  val name = "hidden-strict"
  structure Kernel = BenchHiddenFn (BenchStrict)
  structure Parser = BenchHiddenParseFn (Kernel)
  structure Driver = BenchHiddenDriverFn (structure K = Kernel structure Parser = Parser)
  val run = Driver.run
end
