structure Benchmark =
struct
  structure K = BenchAwardsFn(BenchNeed)
  val name = "awards-lazy"
  fun run [size,path] =
    let val n = BenchInput.between(1,100000)(BenchInput.integer size)
        val input = TextIO.openIn path
        val references = Vector.fromList(String.tokens(fn c => c= #"\n")(TextIO.inputAll input))
        val _ = TextIO.closeIn input
        val _ = if Vector.length references=100 then () else raise Fail "award cycle needs 100 results"
        fun loop i bytes = if i>n then IntInf.toString bytes else
          let val actual = K.render(i mod 100)
              val _ = if actual=Vector.sub(references,(i-1)mod 100) then () else raise Fail "award selection differs"
          in loop(i+1)(IntInf.+(bytes,IntInf.fromInt(String.size actual+1)))end
    in loop 1 0 end
    | run _ = raise Fail "awards expects competitor count reference"
end
