structure Benchmark =
struct
  (* The immediately preceding classic nofib GC wrapper supplies the kernel.
     Its calculation is shared; this spectral driver preserves 500 repetitions. *)
  structure Kernel = Benchmark
  val name = "lcss-nofib-lazy"
  fun run [a,b,c,d,e,f,reference,repetitions] =
    let val times = BenchInput.between (1,500) (BenchInput.integer repetitions)
        val args = [a,b,c,d,e,f,reference]
    in IntInf.toString(BenchInput.repeat times (fn () => BenchInput.integer(Kernel.run args))) end
    | run _ = raise Fail "lcss-nofib expects sequences reference repetitions"
end
