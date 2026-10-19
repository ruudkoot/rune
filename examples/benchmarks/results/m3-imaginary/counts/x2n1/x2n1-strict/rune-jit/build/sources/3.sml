structure Benchmark =
struct
  val name = "x2n1-strict"
  fun run [size] =
    let val n = BenchInput.between (1,1000000) (BenchInput.integer size)
        fun terms i = if i>n then [] else BenchX2N1.consume (i,BenchX2N1.term i) :: terms (i+1)
        val result = List.foldl (fn (value,acc) => BenchX2N1.add(acc,value)) (0.0,0.0) (terms 1)
    in BenchX2N1.validate n result end
    | run _ = raise Fail "x2n1 expects root-count"
end
