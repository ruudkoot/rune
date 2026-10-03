structure Benchmark =
struct
  val name = "rec_seq_evenodd"
  fun even n = if n=0 then true else odd(n-1)
  and odd n = if n=0 then false else even(n-1)
  fun compute n = even n andalso not(odd n)
  fun run [iterations,size] =
    let val r = BenchInput.between(1,1000)(BenchInput.integer iterations)
        val n = BenchInput.between(0,500000000)(BenchInput.integer size)
    in IntInf.toString(BenchInput.repeat r (fn () => if compute n then 1 else 0)) end
    | run _ = raise Fail "rec_seq_evenodd expects repetitions size"
end
