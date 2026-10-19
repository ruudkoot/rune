fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor StatesFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchReptileFn(D)
 structure L=BenchLazy
 fun array values="["^String.concatWith","values^"]"
 fun sequence f values=
   let fun loop values=case D.force values of K.F.Nil=>[]
         |K.F.Cons(value,rest)=>f value::loop rest
   in array(loop values)end
 fun ints values=sequence K.number values
 fun drawing value=let val(a,b)=D.force value in array[ints a,ints b]end
 fun key value=let val(a,b)=D.force value in array[K.number a,K.number b]end
 fun association value=let val(k,v)=D.force value in array[key k,K.number v]end
 fun state value=let val(d,s,t)=L.force value in array[sequence drawing d,K.number s,sequence association t]end
 fun one(profile,name)=
   let val root="tests/out/benchmarks/"
       val input=K.input(read(root^"pinned/nofib/real/reptile/"^name))
       fun loop current input=if K.tilequit current input then[]
         else let val(output,next,rest)=L.force(K.tiletrans current input)
              in array[K.signedHash(K.hash output),state next]::loop next rest end
       val actual=array(loop K.initialState input)^"\n"
       val expected=read(root^"nofib-reptile-originals/state-data/"^profile^".reference")
   in if actual=expected then print("PASS "^label^" "^profile^" complete transition states\n")
      else let val f=TextIO.openOut(root^"nofib-reptile-originals/state-data/"^profile^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("state "^profile)end end
 val _=List.app one[("smoke","reptile.faststdin"),("normal","reptile.stdin"),("large","reptile.slowstdin")]
end
structure NeedStates=StatesFn(structure D=BenchNeed val label="need")
structure StrictStates=StatesFn(structure D=BenchStrict val label="strict")
