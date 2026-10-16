structure NeedAtom=BenchAtomFn(BenchNeed)
structure StrictAtom=BenchAtomFn(BenchStrict)
structure NeedDriver=BenchAtomDriverFn(NeedAtom)
structure StrictDriver=BenchAtomDriverFn(StrictAtom)
structure Pilot =
struct
  val result=case CommandLine.arguments()of
      ["lazy",n,path]=>NeedDriver.run[n,path]
    |["strict",n,path]=>StrictDriver.run[n,path]
    |_=>raise Fail "atom pilot arguments"
  val _=print(result^"\n")
end
