functor BenchHpgRandomFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure C=BenchIdaFiniteFn(BenchNeed)
 structure R=BenchMandelSingle
 fun combine(a,b,c)=R.add(R.add(R.divide(R.round(Real.fromInt a),30269.0),
       R.divide(R.round(Real.fromInt b),30307.0)),R.divide(R.round(Real.fromInt c),30323.0))
 fun step(a,b,c)=((171*a)mod 30269,(172*b)mod 30307,(170*c)mod 30323)
 fun random state=C.defer(fn()=>
   let val value=D.delay(fn()=>let val total=combine state
       in R.sub(total,R.round(Real.fromInt(Real.trunc total)))end)
   in C.cons(L.delay(fn()=>value),random(step state))end)
 fun upto bound value=Real.trunc(R.mul(D.force value,R.round(Real.fromInt(bound+1))))
end
