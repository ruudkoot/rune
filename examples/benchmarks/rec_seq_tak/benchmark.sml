structure Benchmark =
struct
  val name = "rec_seq_tak"
  fun run [iterations,sx,sy,sz] =
    let
      val repetitions = BenchInput.between (1,1000) (BenchInput.integer iterations)
      val x = BenchInput.between (0,40) (BenchInput.integer sx)
      val y = BenchInput.between (0,40) (BenchInput.integer sy)
      val z = BenchInput.between (0,40) (BenchInput.integer sz)
    in
      IntInf.toString (BenchInput.repeat repetitions (fn () => BenchTak.tak(x,y,z)))
    end
    | run _ = raise Fail "rec_seq_tak expects repetitions x y z"
end
