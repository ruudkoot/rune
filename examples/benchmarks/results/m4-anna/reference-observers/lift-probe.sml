fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor LiftTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchAnnaFn(D)
 val p="tests/out/benchmarks/nofib-anna-originals/"
 val allBuiltins=["False","True"]
 val builtins=["_not","_+","_-","_*","_/","_%","_<","_<=","_==","_~=","_>=","_>","_|","_&","_#"]
 val env=K.F.fromList(List.map(fn n=>(K.name(String.extract(n,1,NONE)),K.name n))builtins)
 fun one(profile,file)=let
       val(_,atomic)=K.parseCore(K.input(read(p^"source/"^file)))
       val(_,expression)=D.force atomic
       val depended=K.depend expression
       val merged=K.mergeLambdas depended
       val named=K.nameLambdas merged
       val unique=K.uniqueBody(K.uniqueNames(K.int 0)env named)
       fun check(stage,expression)=let
          val actual=K.observeCore expression
          val expected=read(p^"lift-"^stage^"-"^profile^".reference")
        in if actual=expected then print("PASS "^label^" "^profile^" "^stage^"\n")
           else let val f=TextIO.openOut(p^"lift-"^stage^"-"^profile^"-"^label^".actual")
             in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"lambda-lift stage"end end
    in List.app check[("dependency",depended),("merged",merged),("named",named),("unique",unique)];
       List.app(fn(mode,pretty)=>let
         val names=K.F.fromList(List.map(fn n=>case D.force(K.name n)of node=>node)(builtins@allBuiltins))
         val(e,parameters)=BenchLazy.force(K.lambdaLift names expression pretty)
         val actual="("^K.observeCore e^","^K.showList(fn(n,ps)=>"("^K.quoteName n^","^K.namesShown ps^")")parameters^")"
         val expected=read(p^"lift-final-"^mode^"-"^profile^".reference")
       in if actual=expected then print("PASS "^label^" "^profile^" final-"^mode^"\n")
          else let val f=TextIO.openOut(p^"lift-final-"^mode^"-"^profile^"-"^label^".actual")
            in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"final lambda lifting"end end)
         [("pretty",true),("raw",false)]end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
end
structure Need=LiftTests(structure D=BenchNeed val label="lazy")
structure Strict=LiftTests(structure D=BenchStrict val label="strict")
