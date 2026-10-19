structure Benchmark =
struct
  val name = "expert-lazy"
  structure Program = BenchExpertFn (struct val eagerTerms = false end)
  structure Driver = BenchExpertDriverFn (Program)
  val run = Driver.run
end
