structure LazyGenerator=BenchHartelGenFftFn(BenchNeed)
structure StrictGenerator=BenchHartelGenFftFn(BenchStrict)
structure Pilot =
struct
  fun read name=let val input=TextIO.openIn("tests/out/benchmarks/hartel-fft-originals/genfft/"^name^".program")
                   val value=TextIO.inputAll input val _=TextIO.closeIn input in value end
  val _=List.app(fn(profile,n,expected)=>
    let val data=read profile
        val a=LazyGenerator.check n data val b=StrictGenerator.check n data
        val _=if a=expected andalso b=expected then()else raise Fail "source checksum differs"
    in print("PASS complete generator "^profile^" lazy and strict\n")end)
    [("smoke",3,(417707,5532)),("normal",6,(5925859,79360)),("large",8,(31387091,426210))]
end
