functor BenchHpgCheckFn(K:sig
 type text
 val generate:(int*int*int)->int->int->int->int->int->string->(text->unit)->unit
 val hash:text->Word64.word
 val signedHash:Word64.word->string
end)=struct
 fun run[count,nt,dt,nv,dv,de,h0,h1,h2]=
   let val count=BenchInput.between(0,100000)(BenchInput.integer count)
       val params=List.map(BenchInput.between(0,100000)o BenchInput.integer)[nt,dt,nv,dv,de]
       val(nt,dt,nv,dv,de)=case params of[a,b,c,d,e]=>(a,b,c,d,e)|_=>raise Match
       val hashes=List.map(fn s=>case Word64.fromString("0wx"^s)of SOME w=>w|NONE=>raise Fail"bad source HPG hash")[h0,h1,h2]
       fun iteration()=let val index=ref 0
          fun output chars=let val actual=K.hash chars
              val _=if actual=List.nth(hashes,!index)then()else raise Fail"incorrect result: complete generated HPG chunk"
              val _=TextIO.output(TextIO.stdOut,K.signedHash actual^"\n")
            in index:= !index+1 end
         in K.generate(9807,65,32975)nt dt nv dv de "Main"output;
            if !index=3 then()else raise Fail"incorrect result: HPG chunk count"end
       fun loop n=if n=count then Int.toString n else(iteration();loop(n+1))
   in loop 0 end
  |run _=raise Fail"expected repetitions, source type/value/expression parameters and three modular 64-bit hashes"
end
