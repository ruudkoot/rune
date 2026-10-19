functor BenchTypedBoyerDriverFn(K:sig val test:int->bool end)=
struct
 fun variable name=
  let fun find i=if i=9 then raise Fail "invalid Boyer variable"else
        if Vector.sub(BenchBoyerIds.names,i)=name then i else find(i+1)
  in find 0 end
 fun run[path]=
  let val input=TextIO.openIn path
      fun line()=case TextIO.inputLine input of SOME text=>text|NONE=>raise Fail "short Boyer input"
      fun main()=
        let val repeats=case String.tokens Char.isSpace(line())of[count]=>BenchInput.between(1,100)(BenchInput.integer count)
                         |_=>raise Fail "invalid Boyer repetition count"
            val total=ref 0
            fun once()=
              let val names=String.tokens Char.isSpace(line())
                  val _=if List.length names<=75 then()else raise Fail "Boyer input row too large"
                  fun check []=()|check(name::rest)=
                    if K.test(variable name)then(total:= !total+1;check rest)
                    else raise Fail "incorrect result: Boyer theorem rejected"
              in check names end
            fun loop 0=()|loop n=(once();loop(n-1))
            val _=loop repeats
            val _=case TextIO.inputLine input of NONE=>()|SOME _=>raise Fail "extra Boyer input row"
        in Int.toString repeats^":"^Int.toString(!total)^":proved"end
      val result=main()handle ex=>(TextIO.closeIn input;raise ex)
      val _=TextIO.closeIn input
  in result end
 |run _=raise Fail "Boyer expects deterministic variable input"
end
