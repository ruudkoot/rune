structure Benchmark =
struct
  val name="zarith_pi"
  fun run [size,path] =
    let val n=BenchInput.between(0,10000)(BenchInput.integer size)
        val input=TextIO.openIn path
        val expected=(TextIO.inputAll input handle e=>(TextIO.closeIn input;raise e))
        val _=TextIO.closeIn input
        val _=BenchZarithPi.check n expected
    in Int.toString n^":checked" end
    | run _=raise Fail "zarith_pi expects digit-count reference-file"
end
