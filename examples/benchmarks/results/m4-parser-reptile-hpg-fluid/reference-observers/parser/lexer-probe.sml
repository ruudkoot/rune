fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
functor LexerProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
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
  let val root="tests/out/benchmarks/"
      val input=X.input(read(root^"pinned/nofib/real/parser/"^inputfile))
      fun check phase actual=
        let val expected=read(root^"nofib-parser-originals/stage-data/"^profile^"."^phase)
        in if actual=expected then print("PASS "^label^" "^profile^" "^phase^"\n")
           else let val f=TextIO.openOut(root^"nofib-parser-originals/"^profile^"-"^phase^"-"^label^".actual")
                in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"lexer mismatch"end end
      val _=check"raw"(showTokens(X.lex 1 1 input))
      val _=check"layout"(showTokens(X.main input))
  in()end
 val _=List.app one[("smoke","parser.faststdin"),("normal","parser.stdin"),("large","parser.slowstdin")]
end
structure NeedLexer=LexerProbeFn(structure D=BenchNeed val label="need")
structure StrictLexer=LexerProbeFn(structure D=BenchStrict val label="strict")
