structure NeedMinimax=BenchMinimaxFn(BenchNeed)
structure StrictMinimax=BenchMinimaxFn(BenchStrict)
structure Pilot =
struct
  val a=NeedMinimax.prog "1"
  val b=StrictMinimax.prog "1"
  val input=TextIO.openIn "tests/out/benchmarks/minimax-originals/game.txt"
  val expected=TextIO.inputAll input
  val _=TextIO.closeIn input
  val _=if a=expected andalso b=expected then print("OK "^Int.toString(String.size a)^"\n")
    else raise Fail ("incorrect minimax game: "^a^" / "^b)
end
