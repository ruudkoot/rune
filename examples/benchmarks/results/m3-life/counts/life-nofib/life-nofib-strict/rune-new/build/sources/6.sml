structure Benchmark =
struct
  val name = "life-nofib-strict"
  structure Life = BenchNofibLifeFn(BenchStrict)
  fun run [size,repetitions,reference] =
    let val n = BenchInput.between (1,29) (BenchInput.integer size)
        val times = BenchInput.between (1,250) (BenchInput.integer repetitions)
        val file = TextIO.openIn reference
        val expected = TextIO.inputAll file
        val _ = TextIO.closeIn file
        fun one () =
          let val actual = Life.render(Life.fixpoint n)
          in if actual=expected then String.size actual else raise Fail "Life final generation differs" end
    in IntInf.toString(BenchInput.repeat times one) end
    | run _ = raise Fail "life-nofib expects size repetitions final-display"
end
