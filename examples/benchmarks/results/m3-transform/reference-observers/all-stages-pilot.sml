
functor StagesPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name stage tree=let val actual=K.dumpProgram tree^"\n"
   in if actual=read(name^"-"^stage^"-tree.reference")then print("PASS "^name^"/"^stage^"\n")
      else let val f=TextIO.openOut(name^"-"^stage^"-actual.json")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail(name^"/"^stage)end end
 fun run(name,raw)=let val name=K.showText name
      val prepared=K.label(K.use(K.sorted raw))
      val v0=K.label(K.use(K.sorted(K.inline(K.inline(K.use(K.sorted prepared))))))
      val v1=K.label(K.use(K.sorted(K.t1 v0)))
      val v3=K.label(K.use(K.sorted(K.t3 v1)))
      val v5=K.sorted(K.t5 v3)
      val v6=K.inline(K.t6 v5)
   in check name"v0"v0;check name"v1"v1;check name"v3"v3;check name"v5"v5;check name"v6"v6 end
 val _=List.app run(K.F.toList(K.parsedCases()))
end
structure NeedStages=StagesPilotFn(BenchNeed)
structure StrictStages=StagesPilotFn(BenchStrict)
