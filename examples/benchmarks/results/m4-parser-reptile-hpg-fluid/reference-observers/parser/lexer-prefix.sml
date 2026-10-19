functor BenchNofibParserLexFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure H=BenchParserLiteralsFn(D)
 structure F=H.F
 structure C=BenchIdaFiniteFn(BenchNeed)
 type text=H.text
 val text=H.X.text
 val string=H.X.string
 type input=char C.seq
 fun input s=C.fromList(String.explode s)
 datatype lex=Lcon|Lconop|Lvar|Lvarop|Lintlit|Lcharlit|Lstringlit|Llbrace|Lrbrace|Lsemi|Lequals|Lbar|Larrow|Llparen|Lrparen|Lcomma|Llbrack|Lrbrack|Lunder|Lminus|Lslash|Lmodule|Linfixl|Linfixr|Linfix|Lext|Ldata|Lif|Lthen|Lelse|Llet|Lin|Lcase|Lof|Lwhere|Leof
 type position=int L.delay
 fun pos n=L.delay(fn()=>n)
 fun plus n k=L.delay(fn()=>L.force n+k)
 fun tab n=L.delay(fn()=>L.force n-L.force n mod 8+9)
 type token=position*position*lex*text
 type tokens=token C.seq
 fun token line column tag value=L.delay(fn()=>(line,column,tag,value))
 val eofToken=token(pos 99997)(pos 99997) Leof(text"")
 val eofHolder:tokens option ref=ref NONE
 val eofTokens=L.delay(fn()=>C.Cons(eofToken,case !eofHolder of SOME stream=>stream|NONE=>raise Fail"EOF knot"))
 val _=eofHolder:=SOME eofTokens
 fun next chars=case L.force chars of C.Nil=>NONE|C.Cons(c,rest)=>SOME(L.force c,rest)
 fun singleton value=C.cons(value,C.empty())
 fun fail line column message=raise Fail("\n\nLexical error, line "^Int.toString(L.force line)^", col "^Int.toString(L.force column)^":\n   "^message^"\n")
 val symbols=":!#$%&*+./<=>?\\@^|~"
 fun isSymbol c=String.isSubstring(String.str c)symbols
 fun isTail c=Char.isLower c orelse Char.isUpper c orelse Char.isDigit c orelse c= #"'"orelse c= #"_"
 fun chunk column predicate chars=
   case next chars of NONE=>([],column,chars)
    |SOME(c,rest)=>if predicate c then
        let val(value,column,tail)=chunk(plus column 1)predicate rest in(c::value,column,tail)end
       else([],column,chars)
 fun integer chars=
   let fun value []=0|value(c::rest)=Char.ord c-48+10*value rest
   in value(List.rev chars)end
 fun dropWhile predicate chars=case next chars of SOME(c,rest)=>if predicate c then dropWhile predicate rest else chars|NONE=>chars
 fun dropOne chars=case next chars of NONE=>C.empty()|SOME(_,rest)=>rest
 fun litChars double line column chars=
   case next chars of NONE=>fail line column"End of file inside literal"
    |SOME(c,rest)=>
      let fun prepend c column chars=let val(value,column,tail)=litChars double line column chars in(c::value,column,tail)end
      in if c= #"\\"then(case next rest of
           SOME(d,after)=>(case d of #"\\"=>prepend #"\\"(plus column 2)after
             | #"n"=>prepend #"\n"(plus column 2)after| #"t"=>prepend #"\t"(plus column 2)after
             | #"\""=>prepend #"\""(plus column 2)after| #"'"=>prepend #"'"(plus column 2)after
             |_=>prepend c(plus column 1)rest)
          |NONE=>prepend c(plus column 1)rest)
         else if c= #"\""andalso double orelse c= #"'"andalso not double then([],column,chars)
         else if c= #"\n"then fail line column"Literal exceeds line"
         else if c= #"\t"then fail line column"Literal contains tab"
         else prepend c(plus column 1)rest
      end
