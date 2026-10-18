fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor LR0ProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 structure L=BenchLazy
 structure F=K.F
 structure C=K.C
 fun item(rule,dot)=K.jsonArray[K.jsonInt rule,K.jsonInt dot]
 fun cjson f values=
   let fun loop values=case L.force values of C.Nil=>[]
         |C.Cons(value,rest)=>f(L.force value)::loop rest
   in K.jsonArray(loop values)end
 fun state(set,gotos)=K.jsonArray[K.jsonSequence item(K.itemsToList set),
      cjson(fn(token,index)=>K.jsonArray[K.jsonInt token,Int.toString(L.force index)])gotos]
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/"
       val g=case K.parse(K.X.input(read(root^"grammar-data/"^name^".input")))1 of
          K.X.Ok ast=>(case K.mangler"input.y"ast of K.Succeeded value=>L.force value|_=>raise Fail"mangler")
         |_=>raise Fail"parser"
       val closures=K.precalcClosure0 g
       val actual=K.jsonSequence(fn n=>K.jsonArray[Int.toString n,K.jsonSequence item(closures n)])(K.nonterminals g)^"\n"
       val expected=read(root^"lr0-data/"^name^"-closures.reference")
       val _=if actual=expected then print("PASS "^label^" "^name^" closures\n")
             else raise Fail("LR0 closures mismatch "^name)
       val states=K.genLR0items g closures
       val actual=cjson state states^"\n"
       val expected=read(root^"lr0-data/"^name^"-states.reference")
   in if actual=expected then print("PASS "^label^" "^name^" states\n")
      else let val f=TextIO.openOut(root^"lr0-data/"^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("LR0 states mismatch "^name)end end
 val _=List.app one ["default","basic","precedence","typed","multiple-starts","quote-normalization","attributes","attribute-groups","attribute-rightmost","attribute-zero","attribute-empty","monad-lexer"]
end
structure NeedLR0=LR0ProbeFn(structure D=BenchNeed val label="need")
structure StrictLR0=LR0ProbeFn(structure D=BenchStrict val label="strict")
