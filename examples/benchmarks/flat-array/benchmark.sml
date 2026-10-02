structure Benchmark =
struct
  val name = "flat-array"
  fun run [size,reps] =
    let val n=BenchInput.between(1,1000000)(BenchInput.integer size)
        val count=BenchInput.between(1,10000)(BenchInput.integer reps)
        val v=Vector.tabulate(n,fn i => (Int32.fromInt i,Int32.fromInt(i+1)))
        fun one () = Vector.foldl(fn((a,b),c)=> Int32.+(Int32.+(a,b),c) handle Overflow=>0) 0 v
        fun loop(0,sum)=sum | loop(k,sum)=loop(k-1,IntInf.+(sum,Int32.toLarge(one())))
    in IntInf.toString(loop(count,0)) end
  | run _=raise Fail "flat-array expects length repetitions"
end
