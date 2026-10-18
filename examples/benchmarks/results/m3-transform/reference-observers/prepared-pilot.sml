
functor PreparedPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check(name,tree)=let val name=K.showText name
       val actual=K.dumpProgram(K.label(K.use(K.sorted tree)))^"\n"
   in if actual=read(name^"-prepared-tree.reference")then print("PASS "^name^"\n")
      else let val f=TextIO.openOut(name^"-prepared-actual.json")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail name end end
 val _=List.app check(K.F.toList(K.parsedCases()))
end
structure NeedPrepared=PreparedPilotFn(BenchNeed)
structure StrictPrepared=PreparedPilotFn(BenchStrict)
