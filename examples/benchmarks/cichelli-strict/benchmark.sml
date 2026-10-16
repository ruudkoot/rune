structure Benchmark =
struct
  val name = "cichelli-strict"
  structure Kernel = BenchCichelliFn (struct
    structure Eval = BenchStrict
    val strictCandidates = true
  end)
  structure Driver = BenchCichelliDriverFn (Kernel)
  val run = Driver.run
end
