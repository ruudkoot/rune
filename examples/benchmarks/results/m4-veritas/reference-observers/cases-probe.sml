functor CasesTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchVeritasFn(D)
 structure L=BenchLazy
 val root="tests/out/benchmarks/nofib-veritas-originals/"
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun exists path=(OS.FileSys.access(path,[])handle _=>false)
 fun hex value=String.concat(List.map(fn c=>let val value=Int.fmt StringCvt.HEX(Char.ord c)
     in String.map Char.toLower(if size value=1 then"0"^value else value)end)(K.F.toList value))
 fun proof state=let val K.TreeState(tree,_,_)=D.force state
      val K.Tree(goal,children,done,_,_)=D.force tree
      val K.Goal(_,_,_,uid,_,_,_,_)=D.force goal
      val result=case D.force done of K.NoValue=>"none"|K.SomeValue value=>
         (case D.force value of K.TheoremDone theorem=>"proof:"^hex(K.unparseWrappedTheorem theorem)|_=>"other")
   in K.string uid^":"^Int.toString(D.force(K.length children))^":"^result end
 fun check name phase expected actual=
    if actual=expected then print("PASS "^label^" "^name^" "^phase^"\n")
    else let val f=TextIO.openOut(root^"cases/"^name^"-"^label^"."^phase^".actual")
      in TextIO.output(f,actual);TextIO.closeOut f;raise Fail(name^" "^phase^" "^label)end
 fun one name=
   let val source=root^"cases/"^name
       val input=K.text(read(source^".input"))
   in if exists(source^".protocol")then
      let val output=hex(K.program input)
          val _=check name"protocol"(read(source^".protocol"))output
      in if exists(source^".proof")then check name"proof"(read(source^".proof"))(case L.force(K.editorResult input)of K.Failure message=>"bad="^hex message|K.Success state=>proof(L.force state))
         else print("INCOMPLETE original proof "^name^"\n")end
     else print("INCOMPLETE original protocol "^name^"\n")end
 val _=List.app one(List.filter(fn s=>s<>"")(String.fields(fn c=>c= #"\n")(read(root^"cases/FILES"))))
end
structure Need=CasesTests(structure D=BenchNeed val label="lazy")
structure Strict=CasesTests(structure D=BenchStrict val label="strict")
