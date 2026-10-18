structure SymalgCommands=struct
 structure N=BenchSymalgFn(BenchNeed)
 structure E=BenchSymalgFn(BenchStrict)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 val script=String.fields(fn c=>c= #"\n")(read"commands.stdin")
 val wanted=read"commands.stdout"
 val n=N.transcript script
 val e=E.transcript script
 val _=if n=wanted then print"PASS need command transcript\n"else(print n;raise Fail"need source transcript")
 val _=if e=wanted then print"PASS strict command transcript\n"else(print e;raise Fail"strict source transcript")
end
