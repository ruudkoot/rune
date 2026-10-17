structure Benchmark =
struct
  val name = "typecheck-lazy"
  structure Program = BenchHartelTypecheckProgramFn (struct val eagerChildren = false end)
  structure Driver = BenchHartelTypecheckDriverFn (Program)
  val run = Driver.run
end
