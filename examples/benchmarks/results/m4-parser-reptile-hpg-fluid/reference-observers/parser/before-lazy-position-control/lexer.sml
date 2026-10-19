 fun lex line column chars=C.defer(fn()=>
   let fun emit tag value nextLine nextColumn rest=
         C.cons(token line column tag value,lex nextLine nextColumn rest)
       fun plain tag value rest=emit tag(text value)line(column+1)rest
       fun group first predicate tag rest=
         let val(suffix,finish,tail)=chunk(column+1)predicate rest
         in emit tag(F.fromList(first::suffix))line finish tail end
       fun bracketed first predicate closing rest=
         let val(suffix,finish,tail)=chunk(column+1)predicate rest
         in case next tail of SOME(c,after)=>if c=closing then
               emit Lvar(F.fromList(first::suffix))line(finish+1)after
             else fail line finish"  )  expected"
           |NONE=>fail line finish"  )  expected"end
       fun quoted double rest=
         let val(value,finish,tail)=litChars double line(column+1)rest
             val close=if double then #"\""else #"'"
             val message=if double then"  \"  expected"else"  '  expected"
         in case next tail of NONE=>fail line finish message
           |SOME(c,after)=>if c<>close then fail line finish message
             else if double then emit Lstringlit(F.fromList value)line(finish+1)after
             else if List.length value=1 then emit Lcharlit(F.fromList value)line(finish+1)after
             else fail line(column+1)"Bad character literal"end
   in case next chars of NONE=>eofTokens
    |SOME(c,rest)=>
      if c= #"("then(case next rest of NONE=>singleton(token line column Llparen(text")"))
        |SOME(d,after)=>if d= #":"then bracketed d isTail #")"after
          else if d= #"\\"then plain Llparen"("rest
          else if isSymbol d then bracketed d isSymbol #")"after
          else plain Llparen"("rest)
      else if c=Char.chr 96 then
        (case next rest of SOME(d,after)=>if Char.isAlpha d then
           let val(suffix,finish,tail)=chunk(column+1)Char.isAlpha after
           in case next tail of SOME(e,remaining)=>if e=Char.chr 96 then
                 emit(if Char.isUpper d then Lconop else Lvarop)(F.fromList(d::suffix))line(finish+1)remaining
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
        |SOME(#"-",after)=>rightComment line(column+2)after
        |_=>plain Llbrace"}"rest)
      else if c= #"-"then(case next rest of NONE=>singleton(token line column Lminus(text"-"))
        |SOME(#"-",after)=>leftComment line(column+2)after
        |SOME(#">",after)=>emit Larrow(text"->")line(column+2)after
        |SOME(#"}",_)=>fail line column"Misplaced -}"
        |_=>plain Lminus"-"rest)
      else if c= #" "then lex line(column+1)rest
      else if c= #"\n"then lex(line+1)1 rest
      else if c= #"\t"then lex line(column-column mod 8+9)rest
      else if c= #"#"then if column=1 then
        let val afterFirst=case next rest of NONE=>raise Fail"Prelude.tail: empty list"|SOME(_,tail)=>tail
            val(number,_,_)=chunk 0 Char.isDigit afterFirst
        in lex(integer number)1(dropOne(dropWhile(fn x=>x<> #"\n")rest))end
        else group c isSymbol Lvarop rest
      else if Char.isAlpha c then group c isTail(if Char.isUpper c then Lcon else Lvar)rest
      else if Char.isDigit c then group c Char.isDigit Lintlit rest
      else if isSymbol c then group c isSymbol(if c= #":"then Lconop else Lvarop)rest
      else fail line column("Illegal character  "^String.str c)
   end)
 and leftComment line column chars=lex(line+1)1(dropOne(dropWhile(fn c=>c<> #"\n")chars))
 and rightComment line column chars=C.defer(fn()=>case next chars of
      NONE=>fail line column"End of file inside {- ... -} comment"
     |SOME(#"-",rest)=>(case next rest of SOME(#"}",after)=>lex line(column+2)after
        |_=>rightComment line(column+1)rest)
     |SOME(#"\n",rest)=>rightComment(line+1)1 rest
     |SOME(#"\t",rest)=>rightComment line(column-column mod 8+9)rest
     |SOME(_,rest)=>rightComment line(column+1)rest)
