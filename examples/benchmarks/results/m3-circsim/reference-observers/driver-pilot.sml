structure NeedCircuit=BenchCircsimFn(BenchNeed)
structure StrictCircuit=BenchCircsimFn(BenchStrict)
structure NeedDriver=BenchCircsimDriverFn(NeedCircuit)
structure StrictDriver=BenchCircsimDriverFn(StrictCircuit)
structure Pilot =
struct
  val data="tests/out/benchmarks/circsim-originals/normal.show"
  val _=print("PASS gc lazy normal "^NeedDriver.run false["8","40","97",data]^"\n")
  val _=print("PASS gc strict normal "^StrictDriver.run false["8","40","97",data]^"\n")
  val _=print("PASS spectral lazy normal "^NeedDriver.run true["8","40","97",data]^"\n")
  val _=print("PASS spectral strict normal "^StrictDriver.run true["8","40","97",data]^"\n")
end
