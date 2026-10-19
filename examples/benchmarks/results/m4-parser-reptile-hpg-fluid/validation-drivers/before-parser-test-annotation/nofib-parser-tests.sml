functor NofibParserReportTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibParserFn(D)
 fun one(profile,inputfile)=
  let val root="tests/benchmarks/data/nofib-parser/"
      val chars=K.X.input(BenchApplicationTestIO.read(root^"inputs/"^inputfile))
      val result=K.parse chars
      val actual=K.string(K.report result)
      val expected=BenchApplicationTestIO.read(root^"profiles/"^profile^".result")
  in BenchApplicationTestIO.compare("nofib-parser/"^label^"/"^profile^"/report",expected,actual)end

 val _=List.app one[("smoke","parser.faststdin"),("normal","parser.stdin"),("large","parser.slowstdin")]
end
structure NeedParserReport=NofibParserReportTestsFn(structure D=BenchNeed val label="need")
structure StrictParserReport=NofibParserReportTestsFn(structure D=BenchStrict val label="strict")

functor NofibParserHashTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibParserFn(D)
 fun one(profile,inputfile)=
  let val root="tests/benchmarks/data/nofib-parser/"
      val chars=K.X.input(BenchApplicationTestIO.read(root^"inputs/"^inputfile))
      val result=K.parse chars
      val chars=K.report result
      val actual=K.signedHash(K.hash chars)^"\n"
      val expected=BenchApplicationTestIO.read(root^"profiles/"^profile^".hash")
  in BenchApplicationTestIO.compare("nofib-parser/"^label^"/"^profile^"/hash",expected,actual)end

 val _=List.app one[("smoke","parser.faststdin"),("normal","parser.stdin"),("large","parser.slowstdin")]
end
structure NeedParserHash=NofibParserHashTestsFn(structure D=BenchNeed val label="need")
structure StrictParserHash=NofibParserHashTestsFn(structure D=BenchStrict val label="strict")

functor NofibParserLexerTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure X=BenchNofibParserLexFn(D)
 structure L=BenchLazy
 fun tagName value=case value of X.Lcon=>"Lcon"|X.Lconop=>"Lconop"|X.Lvar=>"Lvar"|X.Lvarop=>"Lvarop"|X.Lintlit=>"Lintlit"|X.Lcharlit=>"Lcharlit"|X.Lstringlit=>"Lstringlit"|X.Llbrace=>"Llbrace"|X.Lrbrace=>"Lrbrace"|X.Lsemi=>"Lsemi"|X.Lequals=>"Lequals"|X.Lbar=>"Lbar"|X.Larrow=>"Larrow"|X.Llparen=>"Llparen"|X.Lrparen=>"Lrparen"|X.Lcomma=>"Lcomma"|X.Llbrack=>"Llbrack"|X.Lrbrack=>"Lrbrack"|X.Lunder=>"Lunder"|X.Lminus=>"Lminus"|X.Lslash=>"Lslash"|X.Lmodule=>"Lmodule"|X.Linfixl=>"Linfixl"|X.Linfixr=>"Linfixr"|X.Linfix=>"Linfix"|X.Lext=>"Lext"|X.Ldata=>"Ldata"|X.Lif=>"Lif"|X.Lthen=>"Lthen"|X.Lelse=>"Lelse"|X.Llet=>"Llet"|X.Lin=>"Lin"|X.Lcase=>"Lcase"|X.Lof=>"Lof"|X.Lwhere=>"Lwhere"|X.Leof=>"Leof"
 fun showToken(line,column,tag,text)=
   "("^Int.toString(L.force line)^","^Int.toString(L.force column)^","^tagName tag^","^
   X.H.showString(List.map Char.ord(X.F.toList text))^")"
 fun showTokens values=
  let fun loop values=case L.force values of X.C.Nil=>[]
        |X.C.Cons(value,rest)=>let val t as(_,_,tag,_)=L.force value
          in showToken t::(if tag=X.Leof then[]else loop rest)end
  in "["^String.concatWith","(loop values)^"]\n"end
 fun one(profile,inputfile)=
  let val root="tests/benchmarks/data/nofib-parser/"
      val input=X.input(BenchApplicationTestIO.read(root^"inputs/"^inputfile))
      fun check phase actual=
        let val expected=BenchApplicationTestIO.read(root^"profiles/"^profile^"."^phase)
        in BenchApplicationTestIO.compare("nofib-parser/"^label^"/"^profile^"/"^phase,expected,actual)end

      val _=check"raw"(showTokens(X.lex 1 1 input))
      val _=check"layout"(showTokens(X.main input))
  in()end
 val _=List.app one[("smoke","parser.faststdin"),("normal","parser.stdin"),("large","parser.slowstdin")]
end
structure NeedLexer=NofibParserLexerTestsFn(structure D=BenchNeed val label="need")
structure StrictLexer=NofibParserLexerTestsFn(structure D=BenchStrict val label="strict")

functor NofibParserLexerCaseTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure X=BenchNofibParserLexFn(D)
 structure L=BenchLazy
 fun tagName value=case value of X.Lcon=>"Lcon"|X.Lconop=>"Lconop"|X.Lvar=>"Lvar"|X.Lvarop=>"Lvarop"|X.Lintlit=>"Lintlit"|X.Lcharlit=>"Lcharlit"|X.Lstringlit=>"Lstringlit"|X.Llbrace=>"Llbrace"|X.Lrbrace=>"Lrbrace"|X.Lsemi=>"Lsemi"|X.Lequals=>"Lequals"|X.Lbar=>"Lbar"|X.Larrow=>"Larrow"|X.Llparen=>"Llparen"|X.Lrparen=>"Lrparen"|X.Lcomma=>"Lcomma"|X.Llbrack=>"Llbrack"|X.Lrbrack=>"Lrbrack"|X.Lunder=>"Lunder"|X.Lminus=>"Lminus"|X.Lslash=>"Lslash"|X.Lmodule=>"Lmodule"|X.Linfixl=>"Linfixl"|X.Linfixr=>"Linfixr"|X.Linfix=>"Linfix"|X.Lext=>"Lext"|X.Ldata=>"Ldata"|X.Lif=>"Lif"|X.Lthen=>"Lthen"|X.Lelse=>"Lelse"|X.Llet=>"Llet"|X.Lin=>"Lin"|X.Lcase=>"Lcase"|X.Lof=>"Lof"|X.Lwhere=>"Lwhere"|X.Leof=>"Leof"
 fun showToken(line,column,tag,text)=
   "("^Int.toString(L.force line)^","^Int.toString(L.force column)^","^tagName tag^","^
   X.H.showString(List.map Char.ord(X.F.toList text))^")"
 fun showTokens values=
  let fun loop values=case L.force values of X.C.Nil=>[]
        |X.C.Cons(value,rest)=>let val t as(_,_,tag,_)=L.force value
          in showToken t::(if tag=X.Leof then[]else loop rest)end
  in "["^String.concatWith","(loop values)^"]\n"end
 fun trim text=
  let fun finish n=if n>0 andalso String.sub(text,n-1)= #"\n"then finish(n-1)else n
  in String.substring(text,0,finish(String.size text))end
 fun actual build=(let val value=showTokens(build())in "ok\n"^value end)
   handle e=>"exception\n"^(case e of Fail message=>message|Match=>"pattern-match"|_=>General.exnName e)
 fun one name=
  let val root="tests/benchmarks/data/nofib-parser/lexer-cases/"
      val input=X.input(BenchApplicationTestIO.read(root^name^".input"))
      fun check mode output=
       let val expected=BenchApplicationTestIO.read(root^name^"."^mode)
           val same=if String.isPrefix"exception\n"expected then trim output=trim expected else output=expected
       in T.check("nofib-parser/"^label^"/lexer/"^name^"/"^mode,fn()=>same)end

      val _=check"raw"(actual(fn()=>X.lex 1 1 input))
      val _=check"layout"(actual(fn()=>X.main input))
  in()end
 val _=List.app one ["case-0","case-1","case-2","case-3","case-4","case-5","case-6","case-7","case-8","case-9","case-10","case-11","case-12","case-13","case-14","case-15","case-16","case-17","case-18","case-19","case-20","case-21","case-22","case-23","case-24","case-25"]
end
structure NeedLexer=NofibParserLexerCaseTestsFn(structure D=BenchNeed val label="need")
structure StrictLexer=NofibParserLexerCaseTestsFn(structure D=BenchStrict val label="strict")

functor NofibParserTypedCaseTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
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
   let val root="tests/benchmarks/data/nofib-parser/parse-cases/"
       val tokens=K.X.main(K.X.input(BenchApplicationTestIO.read(root^name^".input")))
       val env=K.hsPrecTable
       val actual=((case mode of
           "module"=>dump K.showModule(K.paModule env tokens)
          |"expr"=>dump K.showExpr(K.paExpr env tokens)
          |"pat"=>dump K.showPat(K.paPat env tokens)
          |"type"=>dump K.showType(K.paType env tokens)
          |"valdef"=>dump K.showValBind(K.paValdef env tokens)
          |"data"=>dump K.showDataDecl(K.paDataDecl env tokens)
          |_=>raise Fail"mode")handle _=>"exception ")
       val expected=BenchApplicationTestIO.read(root^name^".reference")
       val same=actual=expected orelse
           String.isPrefix"exception "actual andalso String.isPrefix"exception "expected
   in T.check("nofib-parser/"^label^"/typed/"^name^"/"^mode,fn()=>same)end

 val _=List.app one [("case-0","module"),("case-1","module"),("case-2","module"),("case-3","module"),("case-4","module"),("case-5","expr"),("case-6","expr"),("case-7","expr"),("case-8","expr"),("case-9","expr"),("case-10","expr"),("case-11","expr"),("case-12","expr"),("case-13","expr"),("case-14","expr"),("case-15","expr"),("case-16","expr"),("case-17","expr"),("case-18","expr"),("case-19","pat"),("case-20","pat"),("case-21","pat"),("case-22","pat"),("case-23","pat"),("case-24","type"),("case-25","type"),("case-26","type"),("case-27","type"),("case-28","valdef"),("case-29","valdef"),("case-30","data"),("case-31","module"),("case-32","module")]
end
structure NeedCases=NofibParserTypedCaseTestsFn(structure D=BenchNeed val label="need")
structure StrictCases=NofibParserTypedCaseTestsFn(structure D=BenchStrict val label="strict")

functor ParserDemandFn(structure D:BENCH_SUSPEND val strict:bool val label:string)=struct
 structure K=BenchNofibParserFn(D)
 structure L=BenchLazy
 structure X=K.X
 exception Demanded
 val env=K.hsPrecTable
 fun poisonTokens()=L.delay(fn()=>raise Demanded)
 fun failParser _ _=L.delay(fn()=>K.PFail K.eof)
 fun mustSkip _ _=raise Demanded
 fun success result=case L.force result of K.POk _=>true|_=>false
 fun failure result=case L.force result of K.PFail _=>true|_=>false
 fun check name valid=T.check("nofib-parser/"^label^"/demand/"^name,fn()=>valid)
 val _=check"first-empty-alternative-skips-input-and-rest"
   (success(K.pgAlts[K.pgEmpty(K.cell 42),mustSkip]env(poisonTokens())))
 val _=check"sequence-failure-skips-later-parser"
   (failure(K.pgThen2(fn _=>fn _=>raise Demanded)failParser mustSkip env(poisonTokens())))
 val _=check"failed-line-parser-skips-input"
   (failure(K.pgGetLineNumber failParser env(poisonTokens())))
 fun error line=L.delay(fn()=>(X.pos line,L.delay(fn()=>raise Demanded),X.Lvar,X.text""))
 val initial=error 0 val nearer=error 10 val further=error 20
 fun fail token _ _=L.delay(fn()=>K.PFail token)
 val result:int K.result=K.pgAlts[fail nearer,fail further]env(X.C.cons(initial,X.C.empty()))
 val _=check"furthest-line-skips-unused-columns"
   (case L.force result of K.PFail token=>K.tokenLine token=20|_=>false)
 val hits=ref 0
 val parsed=K.pgApply(fn _=>D.delay(fn()=>(hits:= !hits+1;42)))
   (K.pgEmpty(K.cell 0))env(X.C.empty())
 val value=case L.force parsed of K.POk(_,_,value)=>value|_=>raise Fail"success"
 val _=check"semantic-attribute-demand"
   (!hits=(if strict then 1 else 0)andalso D.force value=42 andalso D.force value=42 andalso !hits=1)
end
structure NeedParserDemand=ParserDemandFn(structure D=BenchNeed val strict=false val label="need")
structure StrictParserDemand=ParserDemandFn(structure D=BenchStrict val strict=true val label="strict")
