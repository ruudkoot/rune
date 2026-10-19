structure Benchmark =
struct
  val name = "lazylist"
  fun run [size,iterations] =
    let
      val n = BenchInput.between (0,100000) (BenchInput.integer size)
      val times = BenchInput.between (0,10000) (BenchInput.integer iterations)
      fun loop 0 lengths heads = IntInf.toString lengths ^ ":" ^ IntInf.toString heads
        | loop left lengths heads =
            let val (length,head) = BenchOcamlLazyList.consume(BenchOcamlLazyList.create n)
            in loop (left-1) (IntInf.+(lengths,IntInf.fromInt length))
                 (IntInf.+(heads,IntInf.fromInt head)) end
    in loop (times+1) 0 0 end
    | run _ = raise Fail "lazylist expects length iterations"
end
