structure Benchmark =
struct
  val name = "linear-lazy"
  structure Kernel = BenchLinearFn (BenchNeed)
  structure Driver = BenchLinearDriverFn
    (struct type number = Kernel.number val stats = Kernel.stats val value = Kernel.B.value end)
  val run = Driver.run "real"
end
