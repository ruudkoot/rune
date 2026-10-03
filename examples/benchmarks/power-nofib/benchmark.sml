structure Benchmark =
struct
  val name = "power-nofib"
  structure Workload = BenchPowerWorkloadFn (BenchPowerRational)
  fun run [count,repetitions,reference] =
    let val n = BenchInput.between (1,90) (BenchInput.integer count)
        val times = BenchInput.between (1,200) (BenchInput.integer repetitions)
        val file = TextIO.openIn reference
        val expected = TextIO.inputAll file
        val _ = TextIO.closeIn file
        fun loop (0,total) = total
          | loop (left,total) =
              let val actual = Workload.output n
                  val _ = if actual=expected then () else raise Fail "power series coefficients differ"
              in loop (left-1,total+n) end
    in Int.toString (loop (times,0)) end
    | run _ = raise Fail "power-nofib expects coefficient-count repetitions reference"
end
