structure Benchmark =
struct
  val name = "rec_seq_motzkin"
  fun sum f i stop acc = if i>stop then acc else sum f (i+1) stop (acc+f i)
  fun motz n = if n<=1 then 1 else
    let val limit = n-2
        fun product i = motz i * motz(limit-i)
    in motz(n-1)+sum product 0 limit 0 end
  fun run [iterations,size] =
    let val r = BenchInput.between(1,4)(BenchInput.integer iterations)
        val n = BenchInput.between(0,21)(BenchInput.integer size)
    in IntInf.toString(BenchInput.repeat r (fn () => motz n)) end
    | run _ = raise Fail "rec_seq_motzkin expects repetitions size"
end
