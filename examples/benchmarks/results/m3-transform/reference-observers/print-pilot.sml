functor TransformPrintPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun show text=String.implode(K.F.toList text)
 fun check(name,tree)=
   let val label=show name val text=K.printProgram tree
   in if show text=read(label^"-parse.pretty")then print("PASS "^label^"\n")
      else let val f=TextIO.openOut(label^"-actual.pretty")
           in TextIO.output(f,show text);TextIO.closeOut f;raise Fail label end end
 val _=List.app check(K.F.toList(K.parsedCases()))
end
structure NeedPrint=TransformPrintPilotFn(BenchNeed)
structure StrictPrint=TransformPrintPilotFn(BenchStrict)
