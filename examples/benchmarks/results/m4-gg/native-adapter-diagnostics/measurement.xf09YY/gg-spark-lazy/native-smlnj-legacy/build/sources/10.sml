functor BenchGGDriverFn(D:BENCH_SUSPEND) =
struct
 structure K=BenchGGGraphsFn(D)
 structure C=K.C
 fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
   val _=TextIO.closeIn f in text end
 fun mode "activity"=K.Activity[K.GC,K.REDN,K.IDLE,K.FLUSH]
   |mode "spark"=K.Sparks[K.RESUMED,K.USED,K.CREATED,K.LOST]
   |mode "pool"=K.Pool
   |mode _=raise Fail "unknown GRIP graph mode"
 fun format "landscape"=K.Landscape
   |format "portrait"=K.Portrait
   |format "eps"=K.Encapsulated(15,10)
   |format _=raise Fail "unknown GRIP graph format"
 fun selected "-"=[]
   |selected text=List.map(fn token=>
       let val(pe,rest)=C.processor(String.explode token)
       in if List.null rest then pe else raise Fail "invalid GRIP processor filter"end)
       (String.tokens(fn c=>c= #",")text)
 fun run kind[repeatText,inputPath,referencePath,formatText,processors]=
   let val repeats=BenchInput.between(0,1500)(BenchInput.integer repeatText)
       val graph=mode kind val presentation=format formatText
       val processors=selected processors
       val input=String.explode(read inputPath)
       val wanted=BenchGGCheck.rows(read referencePath)
       fun loop 0 count=Int.toString repeats^":"^Int.toString count
         |loop n count=
           let val lines=BenchGGCheck.consume(K.run graph presentation processors input)wanted
           in loop(n-1)(count+lines)end
   in loop repeats 0 end
   |run _ _=raise Fail "GRIP graph expects repetitions, trace, reference PostScript, format and processor filter"
end
