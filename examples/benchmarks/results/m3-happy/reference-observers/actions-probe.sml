fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor ActionsProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 structure L=BenchLazy
 structure F=K.F
 structure C=K.C
 fun item(rule,dot)=K.jsonArray[K.jsonInt rule,K.jsonInt dot]
 fun names set=K.jsonInts(K.namesFromSet set)
 fun cjson f values=
   let fun loop values=case L.force values of C.Nil=>[]
         |C.Cons(value,rest)=>f(L.force value)::loop rest
   in K.jsonArray(loop values)end
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/"
       val g=case K.parse(K.X.input(read(root^"grammar-data/"^name^".input")))1 of
          K.X.Ok ast=>(case K.mangler"input.y"ast of K.Succeeded value=>L.force value|_=>raise Fail"mangler")
         |_=>raise Fail"parser"
       val first=K.mkFirst g
       val states=K.genLR0items g(K.precalcClosure0 g)
       val(spont,prop)=K.propLookaheads g states first
       fun check mode actual=
         let val expected=read(root^"actions-data/"^name^"-"^mode^".reference")
         in if actual^"\n"=expected then print("PASS "^label^" "^name^" "^mode^"\n")
            else let val f=TextIO.openOut(root^"actions-data/"^name^"-"^mode^"-"^label^".actual")
                 in TextIO.output(f,actual^"\n");TextIO.closeOut f;raise Fail("actions mismatch "^name^" "^mode)end end
       val final=K.calcLookaheads(K.cLength states)spont prop
       val merged=K.mergeLookaheadInfo final states
       fun prio p=case D.force p of K.No=>"[0]"
         |K.Prio(a,n)=>K.jsonArray["1",case D.force a of K.LeftAssoc=>"0"|K.RightAssoc=>"1"|K.NonAssoc=>"2",K.jsonInt n]
       fun action value=case D.force value of
          K.LRShift(n,p)=>K.jsonArray["0",K.jsonInt n,prio p]
         |K.LRReduce(n,p)=>K.jsonArray["1",K.jsonInt n,prio p]
         |K.LRAccept=>"[2]"|K.LRFail=>"[3]"|K.LRMustFail=>"[4]"
         |K.LRMultiple(xs,x)=>K.jsonArray["5",K.jsonSequence(fn x=>action(D.delay(fn()=>x)))xs,action x]
       fun goto value=case D.force value of K.NoGoto=>"[0]"|K.Goto n=>K.jsonArray["1",K.jsonInt n]
       fun table f values=K.jsonSequence(fn(i,row)=>K.jsonArray[Int.toString i,
            K.jsonSequence(fn(n,value)=>K.jsonArray[Int.toString n,f value])(K.A.assocs row)])(K.A.assocs values)
       val gt=K.genGotoTable g states
       val at=K.genActionTable g first merged
       val(perState,counts)=K.countConflicts at
       val _=check"goto"(table goto gt)
       val _=check"action"(table action at)
       fun pair(a,b)=K.jsonArray[Int.toString(L.force a),Int.toString(L.force b)]
       val _=check"per-state"(K.jsonSequence(fn(i,p)=>K.jsonArray[Int.toString i,pair(L.force p)])(K.A.assocs perState))
       val _=check"counts"(pair(L.force counts))
   in()end
 val _=List.app one ["default","basic","precedence","typed","multiple-starts","quote-normalization","attributes","attribute-groups","attribute-rightmost","attribute-zero","attribute-empty","monad-lexer"]
end
structure NeedActions=ActionsProbeFn(structure D=BenchNeed val label="need")
structure StrictActions=ActionsProbeFn(structure D=BenchStrict val label="strict")
