fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor ReptileProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchReptileFn(D)
 fun one(profile,name)=
   let val root="tests/out/benchmarks/"
       val actual=K.signedHash(K.benchmark(K.input(read(root^"pinned/nofib/real/reptile/"^name))))
       val actual=actual^"\n"
       val expected=read(root^"nofib-reptile-originals/stage-data/"^profile^".hash")
   in if actual=expected then print("PASS "^label^" "^profile^" "^Int.toString(String.size actual)^" signed hash bytes\n")
      else let val f=TextIO.openOut(root^"nofib-reptile-originals/"^profile^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("Reptile protocol "^profile)end end
 val _=List.app one[("smoke","reptile.faststdin"),("normal","reptile.stdin"),("large","reptile.slowstdin")]
end
structure NeedReptile=ReptileProbeFn(structure D=BenchNeed val label="need")
structure StrictReptile=ReptileProbeFn(structure D=BenchStrict val label="strict")
