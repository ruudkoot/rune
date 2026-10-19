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
 fun trim text=
  let fun finish n=if n>0 andalso String.sub(text,n-1)= #"\n"then finish(n-1)else n
  in String.substring(text,0,finish(String.size text))end
 fun actual build=(let val value=showTokens(build())in "ok\n"^value end)
   handle e=>"exception\n"^(case e of Fail message=>message|Match=>"pattern-match"|_=>General.exnName e)
 fun one name=
  let val root="tests/out/benchmarks/nofib-parser-originals/lexer-cases/"
      val input=X.input(read(root^name^".input"))
      fun check mode output=
       let val expected=read(root^name^"."^mode)
           val same=if String.isPrefix"exception\n"expected then
             if String.isPrefix"exception\n\n\nLexical error"expected then trim output=trim expected
             else String.isPrefix"exception\n"output
             else output=expected
       in if same then print("PASS "^label^" "^name^" "^mode^"\n")
          else let val f=TextIO.openOut(root^name^"-"^mode^"-"^label^".actual")
               in TextIO.output(f,output);TextIO.closeOut f;raise Fail("lexical case "^name^" "^mode)end end
      val _=check"raw"(actual(fn()=>X.lex 1 1 input))
      val _=check"layout"(actual(fn()=>X.main input))
  in()end
 val _=List.app one ["case-0","case-1","case-2","case-3","case-4","case-5","case-6","case-7","case-8","case-9","case-10","case-11","case-12","case-13","case-14","case-15","case-16","case-17","case-18","case-19","case-20","case-21","case-22","case-23","case-24","case-25"]
end
structure NeedLexer=LexerProbeFn(structure D=BenchNeed val label="need")
structure StrictLexer=LexerProbeFn(structure D=BenchStrict val label="strict")
