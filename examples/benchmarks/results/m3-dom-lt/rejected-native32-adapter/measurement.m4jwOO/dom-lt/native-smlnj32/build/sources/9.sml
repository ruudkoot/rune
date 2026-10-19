structure Benchmark =
struct
  val name = "dom-lt"
  structure Program = BenchDomFn (struct val checkInitialized = false end)
  structure Driver = BenchDomDriverFn (Program)
  val run = Driver.run
end
