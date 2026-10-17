structure NeedPic=BenchPicFn(BenchNeed)
structure StrictPic=BenchPicFn(BenchStrict)
structure NeedDriver=BenchPicDriverFn(NeedPic)
structure StrictDriver=BenchPicDriverFn(StrictPic)
structure Pilot =
struct
 val result=case CommandLine.arguments()of
   ["lazy",n]=>NeedDriver.run[n,"80","tests/out/benchmarks/pic-originals/normal.dt"]
  |["strict",n]=>StrictDriver.run[n,"80","tests/out/benchmarks/pic-originals/normal.dt"]
  |_=>raise Fail "PIC pilot arguments"
 val _=print(result^"\n")
end
