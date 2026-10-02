structure Kernel=struct
 datatype nat=Z|S of nat
 fun number n=if n<1 then Z else S(number(n-1))
 fun add(Z,y)=y|add(S x,y)=S(add(x,y))
 fun multiply(x,Z)=Z|multiply(x,S y)=add(multiply(x,y),x)
 fun power(x,Z)=S Z|power(x,S y)=multiply(x,power(x,y))
 fun integer Z=0|integer(S x)=1+integer x
end
structure Benchmark=struct val name="exp3_8-strict"
 fun run[exponent]=let val n=BenchInput.between(1,9)(BenchInput.integer exponent)
 val result=Kernel.integer(Kernel.power(Kernel.number 3,Kernel.number n))
 fun oracle 0=1|oracle k=3*oracle(k-1)
 in if result=oracle n then Int.toString result else raise Fail "Peano exponentiation"end|run _=raise Fail "exp3_8 expects exponent"end
