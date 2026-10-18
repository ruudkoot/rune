
functor ParstofPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchParstofFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name=let val actual=K.parseJSON(read(name^".input"))^"\n"
       val expected=read(name^"-parse.reference")
   in if actual=expected then print("PASS "^name^"\n")else
     let val f=TextIO.openOut(name^"-parse-actual.json")
     in TextIO.output(f,actual);TextIO.closeOut f;raise Fail name end end
 val _=List.app check["default","identity","application","types","conditional","let-case","lexemes","bad","empty","unterminated-comment"]
end
structure N=ParstofPilotFn(BenchNeed)
structure E=ParstofPilotFn(BenchStrict)
