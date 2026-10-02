structure Benchmark=struct val name="tak-nofib-lazy"
 fun tak(x,y,z)=if not(BenchLazy.force y<BenchLazy.force x)then BenchLazy.force z else
   tak(BenchLazy.delay(fn()=>tak(BenchLazy.delay(fn()=>BenchLazy.force x-1),y,z)),
       BenchLazy.delay(fn()=>tak(BenchLazy.delay(fn()=>BenchLazy.force y-1),z,x)),
       BenchLazy.delay(fn()=>tak(BenchLazy.delay(fn()=>BenchLazy.force z-1),x,y)))
 fun run[x,y,z]=let fun input s=let val n=BenchInput.between(0,40)(BenchInput.integer s)in BenchLazy.delay(fn()=>n)end
   in Int.toString(tak(input x,input y,input z))end|run _=raise Fail "tak expects x y z"end
