structure LazyFft=BenchHartelFftFn(BenchNeed)
structure StrictFft=BenchHartelFftFn(BenchStrict)
structure LazyDriver=BenchHartelFftDriverFn(LazyFft)
structure StrictDriver=BenchHartelFftDriverFn(StrictFft)
structure Pilot =
struct
  val _=print("PASS lazy normal "^LazyDriver.run["3","360"]^"\n")
  val _=print("PASS strict normal "^StrictDriver.run["3","360"]^"\n")
end
