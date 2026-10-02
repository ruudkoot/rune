structure Kernel=struct
 datatype stream=C of IntInf.int * stream BenchLazy.delay
 fun aux n=BenchLazy.delay(fn()=>C(1,BenchLazy.delay(fn()=>C(n,BenchLazy.delay(fn()=>C(1,aux(n+2)))))))
 val continued=BenchLazy.delay(fn()=>C(2,aux 2))
 fun transform(a:IntInf.int,b,c,d,xs)=BenchLazy.delay(fn()=>
   let fun consume()=let val C(x,rest)=BenchLazy.force xs
      in BenchLazy.force(transform(b,a+x*b,d,c+x*d,rest))end
   in if IntInf.sign c=IntInf.sign d orelse IntInf.abs c<IntInf.abs d then
      let val q=IntInf.div(b,d)val cd=c+d
      in if cd*q<=a+b andalso cd*q+cd>a+b
         then C(q,BenchLazy.delay(fn()=>BenchLazy.force(transform(c,d,a-q*c,b-q*d,xs))))
         else consume()end
      else consume()end)
 fun digits n=let
   fun take(0,_,acc)=String.concat(List.rev acc)
     |take(k,xs,acc)=let val C(x,rest)=BenchLazy.force xs
       val _=if x>=0 andalso x<=9 then()else raise Fail "e continued-fraction digit"
       in take(k-1,BenchLazy.delay(fn()=>BenchLazy.force(transform(10,0,0,1,rest))),IntInf.toString x::acc)end
   in take(n,continued,[])end
end
structure Benchmark=struct val name="digits-of-e1-lazy"
 fun run[count,reps,reference]=let val n=BenchInput.between(3,150)(BenchInput.integer count)val r=BenchInput.between(1,100)(BenchInput.integer reps)
 val _=if List.exists(fn p=>p=reference)["expected/smoke.txt","expected/normal.txt","expected/large.txt"]then()else raise Fail "e reference path"
 val input=TextIO.openIn reference val want=TextIO.inputAll input val _=TextIO.closeIn input
 fun one()=let val actual=Kernel.digits n in if actual^"\n"=want then n else raise Fail "e complete digits"end
 in IntInf.toString(BenchInput.repeat r one)end|run _=raise Fail "e expects digit-count repetitions reference"end
