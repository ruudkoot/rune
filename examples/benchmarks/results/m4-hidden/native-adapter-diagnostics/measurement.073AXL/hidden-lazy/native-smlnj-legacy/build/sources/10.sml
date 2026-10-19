structure Benchmark =
struct
  val name = "hidden-lazy"
  structure Kernel = BenchHiddenFn (BenchNeed)
  structure Parser = BenchHiddenParseFn (Kernel)
  structure Driver = BenchHiddenDriverFn (structure K = Kernel structure Parser = Parser)
  val run = Driver.run
end
