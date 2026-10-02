structure Kernel=struct
 datatype nat=Z|S of nat BenchLazy.delay
 type number=nat BenchLazy.delay
 fun number n=BenchLazy.delay(fn()=>if n<1 then Z else S(number(n-1)))
 fun add(x,y)=BenchLazy.delay(fn()=>case BenchLazy.force x of Z=>BenchLazy.force y|S rest=>S(add(rest,y)))
 fun multiply(x,y)=BenchLazy.delay(fn()=>case BenchLazy.force y of Z=>Z|S rest=>BenchLazy.force(add(multiply(x,rest),x)))
 fun power(x,y)=BenchLazy.delay(fn()=>case BenchLazy.force y of Z=>S(number 0)|S rest=>BenchLazy.force(multiply(x,power(x,rest))))
 fun integer n=case BenchLazy.force n of Z=>0|S rest=>1+integer rest
end
structure Benchmark=struct val name="exp3_8-lazy"
 fun run[exponent]=let val n=BenchInput.between(1,9)(BenchInput.integer exponent)
 val result=Kernel.integer(Kernel.power(Kernel.number 3,Kernel.number n))
 fun oracle 0=1|oracle k=3*oracle(k-1)
 in if result=oracle n then Int.toString result else raise Fail "Peano exponentiation"end|run _=raise Fail "exp3_8 expects exponent"end
