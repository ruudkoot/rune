
functor WorkloadPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check(name,input,expected)=
   let val quad=K.prepare(K.text input)val report=K.test quad
       val actual=String.implode(K.F.toList report)
   in if actual=read(name^"-report.reference")andalso K.F.length report=expected
      then print("PASS "^name^"/complete-report\n")
      else let val f=TextIO.openOut(name^"-report-actual.txt")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail name end end
 val _=List.app check BenchTransformInputs.all
 val _=print("SMOKE "^Int.toString(K.run 8 BenchTransformInputs.selected)^"\n")
end
structure NeedWorkload=WorkloadPilotFn(BenchNeed)
structure StrictWorkload=WorkloadPilotFn(BenchStrict)
