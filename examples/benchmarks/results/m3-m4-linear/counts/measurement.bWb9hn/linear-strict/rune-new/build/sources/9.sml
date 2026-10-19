structure Benchmark =
struct
  val name = "linear-strict"
  structure Kernel = BenchLinearFn (BenchStrict)
  structure Driver = BenchLinearDriverFn
    (struct type number = Kernel.number val stats = Kernel.stats val value = Kernel.B.value end)
  val run = Driver.run "real"
end
