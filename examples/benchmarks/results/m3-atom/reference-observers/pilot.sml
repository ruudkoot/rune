structure NeedAtom=BenchAtomFn(BenchNeed)
structure StrictAtom=BenchAtomFn(BenchStrict)
structure NeedDriver=BenchAtomDriverFn(NeedAtom)
structure StrictDriver=BenchAtomDriverFn(StrictAtom)
structure Pilot =
struct
  val file="tests/out/benchmarks/atom-originals/suite-smoke.positions"
  val _=print("PASS lazy smoke "^NeedDriver.run["100",file]^"\n")
  val _=print("PASS strict smoke "^StrictDriver.run["100",file]^"\n")
end
