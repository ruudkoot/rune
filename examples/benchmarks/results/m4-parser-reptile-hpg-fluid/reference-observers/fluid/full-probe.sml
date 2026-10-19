fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor FullTests(D:BENCH_SUSPEND)=struct
 structure K=BenchFluidFn(D)
 val source=K.input(read"tests/out/benchmarks/nofib-fluid-originals/source/fluid.stdin")
 val(file,config as(mon,iterations,tolerance,jacobi,jacobiTolerance,relax,time))=K.readConfig source
 val mesh=K.readMesh(K.input(read("tests/out/benchmarks/nofib-fluid-originals/source/"^file)))
 fun check(name,config)=let
      val actual=K.outputString(K.run config mesh)
      val expected=read("tests/out/benchmarks/nofib-fluid-originals/"^name^".reference")
   in if actual=expected then print("PASS complete source "^name^" "^Int.toString(String.size actual)^" bytes\n")
     else let val f=TextIO.openOut("tests/out/benchmarks/nofib-fluid-originals/"^name^".actual")
       in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("fluid simulation "^name)end end
 val _=List.app check[
   ("fluid-output",config),("fluid-monitor",(true,iterations,tolerance,jacobi,jacobiTolerance,relax,time)),
   ("fluid-two-steps",(false,2,tolerance,jacobi,jacobiTolerance,relax,time)),
   ("fluid-two-steps-monitor",(true,2,tolerance,jacobi,jacobiTolerance,relax,time)),
   ("fluid-tolerance-stop",(false,10,K.number 1.0e6,jacobi,jacobiTolerance,relax,time))]
end
structure Need=FullTests(BenchNeed)
structure Strict=FullTests(BenchStrict)
