fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor ParserProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibParserFn(D)
 fun one(profile,inputfile)=
  let val root="tests/out/benchmarks/"
      val chars=K.X.input(read(root^"pinned/nofib/real/parser/"^inputfile))
      val result=K.parse chars
      val actual=K.string(K.report result)
      val expected=read(root^"nofib-parser-originals/stage-data/"^profile^".result")
  in if actual=expected then print("PASS "^label^" "^profile^" "^Int.toString(String.size actual)^" complete report bytes\n")
     else let val f=TextIO.openOut(root^"nofib-parser-originals/"^profile^"-"^label^".actual")
          in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("parser report "^profile)end end
 val _=List.app one[("smoke","parser.faststdin"),("normal","parser.stdin"),("large","parser.slowstdin")]
end
structure NeedParser=ParserProbeFn(structure D=BenchNeed val label="need")
structure StrictParser=ParserProbeFn(structure D=BenchStrict val label="strict")
