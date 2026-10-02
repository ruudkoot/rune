structure Kernel=struct
 datatype stream=Nil|C of IntInf.int BenchLazy.delay * stream BenchLazy.delay
 fun constant x=BenchLazy.delay(fn()=>x)
 fun initial n=BenchLazy.delay(fn()=>if n=0 then Nil else C(constant 1,initial(n-1)))
 fun tail xs=case BenchLazy.force xs of C(_,rest)=>rest|Nil=>raise Fail "short e series"
 fun head xs=case BenchLazy.force xs of C(value,_)=>BenchLazy.force value|Nil=>raise Fail "short e series"
 fun scale xs=BenchLazy.delay(fn()=>case BenchLazy.force xs of Nil=>Nil|C(value,rest)=>C(BenchLazy.delay(fn()=>10*BenchLazy.force value),scale rest))
 fun carry(base:IntInf.int,xs)=BenchLazy.delay(fn()=>case BenchLazy.force xs of Nil=>raise Fail "e carry exceeded source bound"|C(value,rest)=>
   let val d=BenchLazy.force value val guess=IntInf.div(d,base)val rem=IntInf.mod(d,base)
       val next=carry(base+1,rest)
       val fraction=BenchLazy.delay(fn()=>BenchLazy.force(tail next))
       fun two(first,second)=C(first,BenchLazy.delay(fn()=>C(second,fraction)))
   in if guess=IntInf.div(d+9,base)
      then two(constant guess,BenchLazy.delay(fn()=>rem+head next))
      else let val corrected=d+head next
           in two(constant(IntInf.div(corrected,base)),constant(IntInf.mod(corrected,base)))end end)
 fun digits n=let
   val first=BenchLazy.delay(fn()=>C(constant 2,initial(2*n-1)))
   fun loop(0,_,acc)="2."^String.concat(List.rev acc)
     |loop(k,xs,acc)=let val next=carry(2,scale(tail xs))val digit=head next
       val _=if digit>=0 andalso digit<=9 then()else raise Fail "e carry digit"
       in loop(k-1,next,IntInf.toString digit::acc)end
   in loop(n-2,first,[])end
end
structure Benchmark=struct val name="digits-of-e2-lazy"
 fun run[count,reps,reference]=let val n=BenchInput.between(3,300)(BenchInput.integer count)val r=BenchInput.between(1,100)(BenchInput.integer reps)
 val _=if List.exists(fn p=>p=reference)["expected/smoke.txt","expected/normal.txt","expected/large.txt"]then()else raise Fail "e reference path"
 val input=TextIO.openIn reference val want=TextIO.inputAll input val _=TextIO.closeIn input
 fun one()=let val actual=Kernel.digits n in if actual^"\n"=want then n else raise Fail "e complete digits"end
 in IntInf.toString(BenchInput.repeat r one)end|run _=raise Fail "e expects digit-count repetitions reference"end
