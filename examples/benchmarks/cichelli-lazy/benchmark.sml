structure Benchmark =
struct
  val name = "cichelli-lazy"
  structure Kernel = BenchCichelliFn (struct
    structure Eval = BenchNeed
    val strictCandidates = false
  end)
  structure Driver = BenchCichelliDriverFn (Kernel)
  val run = Driver.run
end
