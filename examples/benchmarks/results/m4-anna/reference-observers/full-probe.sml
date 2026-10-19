functor FullTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchAnnaFn(D)
 val p="tests/out/benchmarks/nofib-anna-originals/"
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun one(profile,file)=
   let val table=K.readTable(K.input(read(p^"source/runtime_files/anna_table")))
       val actual=K.string(K.strictAnalyze table(K.F.empty())(K.input(read(p^"source/"^file))))
       val expected=read(p^"full-"^profile^".reference")
       val out=TextIO.openOut(p^"full-"^profile^"-"^label^".actual")
       val _=TextIO.output(out,actual)
       val _=TextIO.closeOut out
   in if actual=expected then print("PASS "^label^" complete report "^profile^" "^Int.toString(size actual)^"\n")
      else raise Fail("complete report "^profile^" "^label)end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
end
structure Need=FullTests(structure D=BenchNeed val label="lazy")
structure Strict=FullTests(structure D=BenchStrict val label="strict")
