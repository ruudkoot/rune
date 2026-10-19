structure Benchmark =
struct
  structure Join = BenchTreeJoinFn(BenchStrict)
  val name = "treejoin-nofib-strict"
  fun run [first,second,reference,repetitions] =
    let val times = BenchInput.between (1,100) (BenchInput.integer repetitions)
        fun loop 0 = raise Fail "empty join repetition"
          | loop 1 = Join.run[first,second,reference]
          | loop left = (Join.run[first,second,reference];loop(left-1))
    in loop times end
    | run _ = raise Fail "treejoin-nofib expects relations reference repetitions"
end
