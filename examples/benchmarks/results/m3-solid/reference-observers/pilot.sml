structure SolidPilot=struct
 structure N=BenchSolidFn(BenchNeed)
 structure E=BenchSolidFn(BenchStrict)
 fun read file=let val stream=TextIO.openIn file in TextIO.inputAll stream before TextIO.closeIn stream end
 val scene=read"scene.input"
 val rows=String.tokens(fn c=>c= #"\n")(read"repaired-areas.reference")
 fun number text=case Int.fromString text of SOME n=>n|NONE=>raise Fail"bad reference count"
 fun power 0 n=n|power d n=power(d-1)(n*4)
 fun test row=
   case String.tokens Char.isSpace row of[depthText,_,countText]=>
     let val depth=number depthText val expected=number countText
         val need=N.solution scene depth
         val strict=E.solution scene depth
         val a=N.area need val b=E.area strict
         val _=if Real.==(a*Real.fromInt(power depth 1),Real.fromInt expected)andalso Real.==(a,b)then()
               else raise Fail("incorrect area at depth "^depthText)
         val _=if depth<=9 then
            let val expectedShape=read("shape-"^depthText^".reference")
                val actualN=N.shape need^"\n" val actualE=E.shape strict^"\n"
            in if actualN=expectedShape andalso actualE=expectedShape then()else raise Fail("tree shape "^depthText)end
           else()
     in print("PASS "^depthText^" "^Int.toString expected^"\n");TextIO.flushOut TextIO.stdOut end
    |_=>raise Fail"bad area reference"
 val _=List.app test rows
end
