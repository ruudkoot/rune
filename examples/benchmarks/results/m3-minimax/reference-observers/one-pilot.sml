structure NeedMinimax=BenchMinimaxFn(BenchNeed)
structure StrictMinimax=BenchMinimaxFn(BenchStrict)
structure NeedDriver=BenchMinimaxDriverFn(NeedMinimax)
structure StrictDriver=BenchMinimaxDriverFn(StrictMinimax)
structure Pilot =
struct
  val result=case CommandLine.arguments()of
      ["lazy",n]=>NeedDriver.run[n,"tests/out/benchmarks/minimax-originals/game.txt"]
    | ["strict",n]=>StrictDriver.run[n,"tests/out/benchmarks/minimax-originals/game.txt"]
    | _=>raise Fail "minimax pilot arguments"
  val _=print(result^"\n")
end
