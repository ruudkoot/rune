
functor ParsePilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchTransformFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name stage actual=
   if actual^"\n"=read(name^"-"^stage^".reference")then print("PASS "^name^"/"^stage^"\n")
   else let val f=TextIO.openOut(name^"-"^stage^"-actual.json")
        in TextIO.output(f,actual);TextIO.closeOut f;raise Fail(name^"/"^stage)end
 fun run name=
   let val input=K.text(read(name^".input"))
       val tokens=K.lexer input
       val raw=K.parse(K.dropPragma tokens)
       val _=check name"tokens"(K.dumpTokens tokens)
       val _=check name"parse"(K.dumpProgram raw)
       val prepared=K.label(K.use(K.sorted raw))
   in()end
 val _=List.app run["simple","fib","fibsum","tailtest","setreset","flipflop","wave4","wavestream","hamming","gamma","fft"]
end
structure NeedParse=ParsePilotFn(BenchNeed)
structure StrictParse=ParsePilotFn(BenchStrict)
