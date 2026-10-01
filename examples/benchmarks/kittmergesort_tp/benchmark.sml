structure Benchmark =
struct
  val name="kittmergesort_tp"
  fun run [size,reps] =
    let val n=BenchInput.between(1,100)(BenchInput.integer reps)
        fun loop(0,values)=String.concatWith ";" (List.rev values)
          | loop(k,values)=loop(k-1,BenchKittSort.run[size]::values)
    in loop(n,[]) end
  | run _=raise Fail "kittmergesort_tp expects size repetitions"
end
