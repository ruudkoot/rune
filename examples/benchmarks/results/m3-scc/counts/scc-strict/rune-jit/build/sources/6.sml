structure Benchmark =
struct
  structure K = BenchSccFn(BenchStrict)
  val name = "scc-strict"
  fun run [repetitions,path] =
    let val times = BenchInput.between(1,10000)(BenchInput.integer repetitions)
        val input = TextIO.openIn path
        val expected = TextIO.inputAll input
        val _ = TextIO.closeIn input
        fun loop 0 bytes = IntInf.toString bytes
          | loop left bytes =
              let val actual = K.render(K.components K.edges K.vertices) ^ "\n"
                  val _ = if actual=expected then () else raise Fail "SCC component order differs"
              in loop(left-1)(IntInf.+(bytes,IntInf.fromInt(String.size actual))) end
    in loop times 0 end
    | run _ = raise Fail "scc expects repetitions reference"
end
