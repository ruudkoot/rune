structure Benchmark =
struct
  val name="pidigits5"
  fun run [count,path]=
    let val n=BenchInput.between(0,10000)(BenchInput.integer count)
        val input=TextIO.openIn path val expected=TextIO.inputAll input
        val _=TextIO.closeIn input val _=BenchPiDigitsFive.check n expected
    in Int.toString n^":checked"end
    | run _=raise Fail "pidigits5 expects digit count and complete reference"
end
