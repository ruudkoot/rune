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
 fun lexControl line column chars=C.defer(fn()=>
   let fun emit tag value nextLine nextColumn rest=
         C.cons(token line column tag value,lexControl nextLine nextColumn rest)
       fun plain tag value rest=emit tag(text value)line(plus column 1)rest
       fun group first predicate tag rest=
         let val(suffix,finish,tail)=chunk(plus column 1)predicate rest
         in emit tag(F.fromList(first::suffix))line finish tail end
       fun bracketed first predicate closing rest=
         let val(suffix,finish,tail)=chunk(plus column 1)predicate rest
         in case next tail of SOME(c,after)=>if c=closing then
               emit Lvar(F.fromList(first::suffix))line(plus finish 1)after
             else fail line finish"  )  expected"
           |NONE=>fail line finish"  )  expected"end
       fun quoted double rest=
         let val(value,finish,tail)=litChars double line(plus column 1)rest
             val close=if double then #"\""else #"'"
             val message=if double then"  \"  expected"else"  '  expected"
         in case next tail of NONE=>fail line finish message
           |SOME(c,after)=>if c<>close then fail line finish message
             else if double then emit Lstringlit(F.fromList value)line(plus finish 1)after
             else if List.length value=1 then emit Lcharlit(F.fromList value)line(plus finish 1)after
             else fail line(plus column 1)"Bad character literal"end
   in case next chars of NONE=>eofTokens
    |SOME(c,rest)=>
      if c= #"("then(case next rest of NONE=>singleton(token line column Llparen(text")"))
        |SOME(d,after)=>if d= #":"then bracketed d isTail #")"after
          else if d= #"\\"then plain Llparen"("rest
          else if isSymbol d then bracketed d isSymbol #")"after
          else plain Llparen"("rest)
      else if c=Char.chr 96 then
        (case next rest of SOME(d,after)=>if Char.isAlpha d then
           let val(suffix,finish,tail)=chunk(plus column 1)Char.isAlpha after
           in case next tail of SOME(e,remaining)=>if e=Char.chr 96 then
                 emit(if Char.isUpper d then Lconop else Lvarop)(F.fromList(d::suffix))line(plus finish 1)remaining
                else fail line finish"  `  expected"
             |NONE=>fail line finish"  `  expected"end
           else fail line column"Bad infix operator"
         |NONE=>if isSymbol c then group c isSymbol Lvarop rest
            else fail line column("Illegal character  "^String.str c))
      else if c= #"\""then quoted true rest
      else if c= #"'"then quoted false rest
      else if c= #"}"then plain Lrbrace"}"rest
      else if c= #")"then plain Lrparen")"rest
      else if c= #"["then plain Llbrack"["rest
      else if c= #"]"then plain Lrbrack"]"rest
      else if c= #";"then plain Lsemi";"rest
      else if c= #","then plain Lcomma","rest
      else if c= #"_"then plain Lunder"_"rest
      else if c= #"{"then(case next rest of NONE=>singleton(token line column Llbrace(text"}"))
        |SOME(#"-",after)=>rightComment line(plus column 2)after
        |_=>plain Llbrace"}"rest)
      else if c= #"-"then(case next rest of NONE=>singleton(token line column Lminus(text"-"))
        |SOME(#"-",after)=>leftComment line(plus column 2)after
        |SOME(#">",after)=>emit Larrow(text"->")line(plus column 2)after
        |SOME(#"}",_)=>fail line column"Misplaced -}"
        |_=>plain Lminus"-"rest)
      else if c= #" "then lexControl line(plus column 1)rest
      else if c= #"\n"then lexControl(plus line 1)(pos 1) rest
      else if c= #"\t"then lexControl line(tab column)rest
      else if c= #"#"then if L.force column=1 then
        let val number=L.delay(fn()=>
              let val afterFirst=case next rest of NONE=>raise Fail"Prelude.tail: empty list"|SOME(_,tail)=>tail
                  val(digits,_,_)=chunk(pos 0)Char.isDigit afterFirst
              in integer digits end)
        in lexControl number(pos 1)(dropOne(dropWhile(fn x=>x<> #"\n")rest))end
        else group c isSymbol Lvarop rest
      else if Char.isAlpha c then group c isTail(if Char.isUpper c then Lcon else Lvar)rest
      else if Char.isDigit c then group c Char.isDigit Lintlit rest
      else if isSymbol c then group c isSymbol(if c= #":"then Lconop else Lvarop)rest
      else fail line column("Illegal character  "^String.str c)
   end)
 and leftComment line column chars=lexControl(plus line 1)(pos 1)(dropOne(dropWhile(fn c=>c<> #"\n")chars))
 and rightComment line column chars=C.defer(fn()=>case next chars of
      NONE=>fail line column"End of file inside {- ... -} comment"
     |SOME(#"-",rest)=>(case next rest of SOME(#"}",after)=>lexControl line(plus column 2)after
        |_=>rightComment line(plus column 1)rest)
     |SOME(#"\n",rest)=>rightComment(plus line 1)(pos 1) rest
     |SOME(#"\t",rest)=>rightComment line(tab column)rest
     |SOME(_,rest)=>rightComment line(plus column 1)rest)

 fun lex line column chars=lexControl(pos line)(pos column)chars
 fun sameLiteral chars wanted=
   let fun loop i chars=case D.force chars of F.Nil=>i=String.size wanted
         |F.Cons(c,rest)=>i<String.size wanted andalso D.force c=String.sub(wanted,i)andalso loop(i+1)rest
   in loop 0 chars end
 fun keyword(line,column,tag,value)=
   let fun find []=tag|find((word,result)::rest)=if sameLiteral value word then result else find rest
       val result=case tag of
           Lvarop=>find[("=",Lequals),("|",Lbar),("\\",Lslash)]
          |Lvar=>find[("module",Lmodule),("infix",Linfix),("infixl",Linfixl),("infixr",Linfixr),
             ("ext",Lext),("data",Ldata),("if",Lif),("then",Lthen),("else",Lelse),
             ("let",Llet),("in",Lin),("case",Lcase),("of",Lof),("where",Lwhere)]
          |_=>tag
   in(line,column,result,value)end
 fun mapTokens f values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
   |C.Cons(value,rest)=>C.cons(L.delay(fn()=>f(L.force value)),mapTokens f rest))
 fun closeBraces count line column=C.defer(fn()=>if count<=0 then C.empty()
   else C.cons(token line column Lrbrace(text"}"),closeBraces(count-1)line column))
 fun layout line stack values=C.defer(fn()=>
   case L.force values of C.Nil=>closeBraces(List.length stack-1)(pos 99999)(pos 99999)
    |C.Cons(first,remaining)=>(case L.force remaining of
       C.Nil=>C.cons(first,closeBraces(List.length stack-1)(pos 99998)(pos 99998))
      |C.Cons(second,tail)=>
        let val(l1,n1,w1,_)=L.force first val(l2,n2,w2,_)=L.force second
        in case stack of []=>raise Match
         |indent::rest=>
          if(w1=Lof orelse w1=Llet orelse w1=Lwhere)andalso w2<>Llbrace then
             C.cons(first,C.cons(token l1 n1 Llbrace(text"{"),C.cons(second,layout l2(n2::indent::rest)tail)))
          else if L.force l1=L.force line then C.cons(first,layout line stack remaining)
          else if L.force n1>L.force indent then C.cons(first,layout l1 stack remaining)
          else if L.force n1=L.force indent then C.cons(token l1 n1 Lsemi(text";"),C.cons(first,layout l1 stack remaining))
          else C.cons(token l1 n1 Lrbrace(text"}"),layout line rest values)
        end))
 fun main chars=layout(pos 1)[pos 0](mapTokens keyword(lex 1 1 chars))
end
