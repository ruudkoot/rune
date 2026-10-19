fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor TypeTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchAnnaFn(D)
 val p="tests/out/benchmarks/nofib-anna-originals/"
 val builtinNames=K.F.cons(K.name"False",K.F.cons(K.name"True",K.map(fn entry=>let val(n,_)=D.force entry in n end)K.baseTypes))
 fun check name actual=
   let val expected=read(p^name^".reference")
   in if actual=expected then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(p^name^"-"^label^".actual")
        in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"source type inference"end end
 fun one(profile,file)=
   let val(_,atomic)=K.parseCore(K.input(read(p^"source/"^file)))
       val(types,e)=D.force atomic
       val(e,_)=BenchLazy.force(K.lambdaLift builtinNames e true)
       val(words,result)=K.checkTypes K.baseTypes(K.singleton(K.int 1),K.singleton(K.int 0))(K.pair types e)
       val _=check("types-"^profile)(K.string words)
       val(tree,environment)=case BenchLazy.force result of K.Ok value=>D.force value|_=>raise Fail"source typecheck failed"
       val _=check("typed-tree-"^profile)(K.observeTyped tree)
       val _=check("eta-tree-"^profile)(K.observeTyped(K.etaAbstract tree))
       val _=check("type-environment-"^profile)(K.showList(fn(n,t)=>"("^K.quoteName n^","^K.observeType t^")")environment)
   in()end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
end
structure Need=TypeTests(structure D=BenchNeed val label="lazy")
structure Strict=TypeTests(structure D=BenchStrict val label="strict")
