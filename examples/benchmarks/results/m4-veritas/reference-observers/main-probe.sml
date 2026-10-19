functor MainTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchVeritasFn(D)
 val root="tests/out/benchmarks/nofib-veritas-originals/"
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 val output=K.program(K.text(read(root^"source/veritas.stdin")))
 fun hex value=String.concat(List.map(fn c=>let val value=Int.fmt StringCvt.HEX(Char.ord c)
     in String.map Char.toLower(if size value=1 then"0"^value else value)end)(K.F.toList value))
 val actual=hex output
 val expected=read(root^"full-protocol.reference")
 val f=TextIO.openOut(root^"full-protocol-"^label^".actual")
 val _=TextIO.output(f,actual)
 val _=TextIO.closeOut f
 val _=if actual=expected then print("PASS "^label^" full protocol "^Int.toString(size actual div 2)^" bytes\n")
      else raise Fail("full protocol "^label)
end
structure Need=MainTests(structure D=BenchNeed val label="lazy")
structure Strict=MainTests(structure D=BenchStrict val label="strict")
