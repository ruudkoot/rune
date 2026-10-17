structure NeedPrime=BenchPrimeTestFn(BenchNeed)
structure StrictPrime=BenchPrimeTestFn(BenchStrict)
structure Pilot =
struct
  val result=case CommandLine.arguments()of [mode,rounds,path]=>
    let val input=TextIO.openIn path val text=TextIO.inputAll input val _=TextIO.closeIn input
        val lines=String.tokens(fn c=>c= #"\n")text
        val count=valOf(Int.fromString rounds)
    in case mode of "lazy"=>NeedPrime.process count lines
      |"strict"=>StrictPrime.process count lines|_=>raise Fail "unknown policy"end
    |_=>raise Fail "primetest pilot arguments"
  val _=print(result^"\n")
end
