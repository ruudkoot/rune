fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor CasesProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibParserFn(D)
 structure L=BenchLazy
 fun output builder=K.string(K.B.output builder)
 fun dump show result=case L.force result of
    K.PFail token=>"fail "^output(K.showToken token)^"\n"
   |K.POk(env,tokens,value)=>
      let fun entry value=K.B.delayed(fn()=>let val(name,p)=D.force value
           in K.showTuple[K.showText name,K.showPriority p]end)
      in "ok "^output(K.showList(fn _=>entry)env)^" "^output(K.showToken(K.firstToken tokens))^
        " "^output(show 0 value)^"\n"end
 fun one(name,mode)=
   let val root="tests/out/benchmarks/nofib-parser-originals/parse-cases/"
       val tokens=K.X.main(K.X.input(read(root^name^".input")))
       val env=K.hsPrecTable
       val actual=((case mode of
           "module"=>dump K.showModule(K.paModule env tokens)
          |"expr"=>dump K.showExpr(K.paExpr env tokens)
          |"pat"=>dump K.showPat(K.paPat env tokens)
          |"type"=>dump K.showType(K.paType env tokens)
          |"valdef"=>dump K.showValBind(K.paValdef env tokens)
          |"data"=>dump K.showDataDecl(K.paDataDecl env tokens)
          |_=>raise Fail"mode")handle _=>"exception ")
       val expected=read(root^name^".reference")
       val same=actual=expected orelse
           String.isPrefix"exception "actual andalso String.isPrefix"exception "expected
   in if same then print("PASS "^label^" "^name^" "^mode^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;raise Fail("parser case "^name)end end
 val _=List.app one [("case-0","module"),("case-1","module"),("case-2","module"),("case-3","module"),("case-4","module"),("case-5","expr"),("case-6","expr"),("case-7","expr"),("case-8","expr"),("case-9","expr"),("case-10","expr"),("case-11","expr"),("case-12","expr"),("case-13","expr"),("case-14","expr"),("case-15","expr"),("case-16","expr"),("case-17","expr"),("case-18","expr"),("case-19","pat"),("case-20","pat"),("case-21","pat"),("case-22","pat"),("case-23","pat"),("case-24","type"),("case-25","type"),("case-26","type"),("case-27","type"),("case-28","valdef"),("case-29","valdef"),("case-30","data"),("case-31","module"),("case-32","module")]
end
structure NeedCases=CasesProbeFn(structure D=BenchNeed val label="need")
structure StrictCases=CasesProbeFn(structure D=BenchStrict val label="strict")
