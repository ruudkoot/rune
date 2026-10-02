structure Benchmark =
struct
  val name = "rec_seq_ack"
  fun ack m n =
    if m = 0 then n+1
    else if n = 0 then ack (m-1) 1
    else ack (m-1) (ack m (n-1))
  fun run [iterations,sm,sn] =
    let val r = BenchInput.between (1,1000) (BenchInput.integer iterations)
        val m = BenchInput.between (0,3) (BenchInput.integer sm)
        val n = BenchInput.between (0,11) (BenchInput.integer sn)
    in IntInf.toString (BenchInput.repeat r (fn () => ack m n)) end
    | run _ = raise Fail "rec_seq_ack expects repetitions m n"
end
