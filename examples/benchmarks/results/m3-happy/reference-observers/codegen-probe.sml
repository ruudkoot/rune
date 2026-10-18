fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor CodegenProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D) structure L=BenchLazy structure F=K.F
 fun one name=
  let val root="tests/out/benchmarks/nofib-happy-originals/"
      val ast=case K.parse(K.X.input(read(root^"grammar-data/"^name^".input")))1 of K.X.Ok ast=>ast|_=>raise Fail"parser"
      val g=case K.mangler"input.y"ast of K.Succeeded value=>L.force value|_=>raise Fail"mangler"
      val K.AbsSyn(hd,_,_,tl)=D.force ast
      val header=D.delay(fn()=>SOME(F.append(case D.force hd of NONE=>K.emptyText|SOME t=>t)(K.X.text"\n")))
      val first=K.mkFirst g
      val states=K.genLR0items g(K.precalcClosure0 g)
      val(spont,prop)=K.propLookaheads g states first
      val final=K.calcLookaheads(K.cLength states)spont prop
      val merged=K.mergeLookaheadInfo final states
      val output=K.produceParser g(K.genActionTable g first merged)(K.genGotoTable g states)header tl
      val expected=read(root^"codegen-data/"^name^".reference")
      fun loop index chars=case D.force chars of F.Nil=>
            if index=String.size expected then index else raise Fail("short output at "^Int.toString index)
         |F.Cons(value,rest)=>if index>=String.size expected then raise Fail("long output at "^Int.toString index)
            else if D.force value=String.sub(expected,index)then loop(index+1)rest
            else raise Fail("different output at "^Int.toString index^" expected "^Int.toString(Char.ord(String.sub(expected,index)))^" got "^Int.toString(Char.ord(D.force value)))
      val count=(loop 0 output handle Fail message=>
          let val f=TextIO.openOut(root^"codegen-data/"^name^"-"^label^".actual")
              fun write chars=case D.force chars of F.Nil=>()|F.Cons(value,rest)=>
                   (TextIO.output1(f,D.force value);write rest)
          in write output;TextIO.closeOut f;raise Fail(label^" "^name^": "^message)end)
  in print("PASS "^label^" "^name^" "^Int.toString count^" bytes\n")end
 val _=List.app one ["basic","precedence","typed","multiple-starts","quote-normalization","attributes","attribute-groups","attribute-rightmost","attribute-zero","attribute-empty","monad-lexer","default"]
end
structure NeedCodegen=CodegenProbeFn(structure D=BenchNeed val label="need")
structure StrictCodegen=CodegenProbeFn(structure D=BenchStrict val label="strict")
