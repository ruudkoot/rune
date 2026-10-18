fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor HappyParserProbeFn(structure D:BENCH_SUSPEND val label:string)=
struct
 structure K=BenchHappyFn(D)
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/parser-data/"
       val actual=K.parseJSON(read(root^name^".input"))^"\n"
       val expected=read(root^name^".reference")
   in if actual=expected then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("Happy parser mismatch "^name^" "^label)end
   end
 val _=List.app one ["default","basic","empty","typed","directives","multiple-rules","syntax-error","missing-separator","unknown-directive","unterminated-code","missing-id","extra-code"]
end
structure NeedHappyParser=HappyParserProbeFn(structure D=BenchNeed val label="need")
structure StrictHappyParser=HappyParserProbeFn(structure D=BenchStrict val label="strict")
