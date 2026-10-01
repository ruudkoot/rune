structure Benchmark =
struct
  val name="many_refs"
  fun run [size,iterations]=
    let val n=BenchInput.between(1,100000)(BenchInput.integer size)
        val count=BenchInput.between(1,100000)(BenchInput.integer iterations)
        fun gen_ref _=ref 0.0
        fun inc_ref r=r:= !r+1.0
        fun ref_table()=Array.tabulate(n,gen_ref)
        fun inc_table t=Array.app inc_ref t
        val(t1,t2,t3)=(ref_table(),ref_table(),ref_table())
        fun loop 0=() | loop k=(inc_table t1;inc_table t2;inc_table t3;loop(k-1))
        val _=loop count
        fun check t=Array.foldl(fn(r,sum)=>if Real.==(!r,Real.fromInt count) then IntInf.+(sum,IntInf.fromInt count)
                                         else raise Fail "reference increment")0 t
    in IntInf.toString(IntInf.+(check t1,IntInf.+(check t2,check t3))) end
  | run _=raise Fail "many_refs expects table-length increments"
end
