structure LazyGenerator=BenchHartelGenFftFn(BenchNeed)
structure StrictGenerator=BenchHartelGenFftFn(BenchStrict)
structure LazyDriver=BenchHartelGenFftDriverFn(LazyGenerator)
structure StrictDriver=BenchHartelGenFftDriverFn(StrictGenerator)
structure Pilot =
struct
  val input="tests/out/benchmarks/hartel-fft-originals/genfft/normal.program"
  val _=print("PASS lazy normal "^LazyDriver.run["6","300",input]^"\n")
  val _=print("PASS strict normal "^StrictDriver.run["6","300",input]^"\n")
end
