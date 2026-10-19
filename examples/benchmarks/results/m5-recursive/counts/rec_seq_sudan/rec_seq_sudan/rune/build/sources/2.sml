structure Benchmark =
struct
  val name = "rec_seq_sudan"
  (* Selected OCaml 63-bit results/accumulators fit that width but exceed 31 bits.
     Portable IntInf retains the values on every SML host. *)
  fun sudan n (x:IntInf.int) (y:IntInf.int) =
    if n=0 then IntInf.+(x,y)
    else if y=0 then x
    else let val inner = sudan n x (IntInf.-(y,1))
         in sudan(n-1)inner(IntInf.+(inner,y)) end
  fun run [iterations,order,sx,sy] =
    let val r = BenchInput.between(1,10000000)(BenchInput.integer iterations)
        val n = BenchInput.between(0,2)(BenchInput.integer order)
        val x = IntInf.fromInt(BenchInput.between(0,2)(BenchInput.integer sx))
        val y = IntInf.fromInt(BenchInput.between(0,2)(BenchInput.integer sy))
        fun loop 0 total = total
          | loop left total = loop(left-1)(IntInf.+(total,sudan n x y))
    in IntInf.toString(loop r 0) end
    | run _ = raise Fail "rec_seq_sudan expects repetitions order x y"
end
