structure Benchmark =
struct
  val name = "expert-strict"
  structure Program = BenchExpertFn (struct val eagerTerms = true end)
  structure Driver = BenchExpertDriverFn (Program)
  val run = Driver.run
end
