structure SymalgSmokePilot=struct
 structure N=BenchSymalgFn(BenchNeed)
 structure E=BenchSymalgFn(BenchStrict)
 val script=["$prec = 20","sqrt(2)","sqrt(3)","sqrt(4)","sqrt(5)","sqrt(6)","sqrt(7)","sqrt(8)","sqrt(9)","sqrt(10)","exit"]
 val n=N.transcript script
 val e=E.transcript script
 val _=print n
 val _=if n=e then print"POLICIES AGREE\n"else raise Fail"policy transcript"
end
