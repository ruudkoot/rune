structure Benchmark =
struct
  val name = "typecheck-strict"
  structure Program = BenchHartelTypecheckProgramFn (struct val eagerChildren = true end)
  structure Driver = BenchHartelTypecheckDriverFn (Program)
  val run = Driver.run
end
