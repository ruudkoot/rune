 datatype 'a controlNode=CEmpty|CNext of 'a L.delay*'a controlNode L.delay
 type 'a control='a controlNode L.delay
 type tokenStream=token control
 fun cEmpty()=L.delay(fn()=>CEmpty)
 fun cOne value=L.delay(fn()=>CNext(L.delay(fn()=>value),cEmpty()))
 fun cAppend first last=L.delay(fn()=>case L.force first of CEmpty=>L.force last
   |CNext(value,rest)=>CNext(value,cAppend rest last))
 fun cTake 0 _=cEmpty()
   |cTake n values=L.delay(fn()=>case L.force values of CEmpty=>CEmpty
     |CNext(value,rest)=>CNext(value,cTake(n-1)rest))
 fun cMap f values=L.delay(fn()=>case L.force values of CEmpty=>CEmpty
   |CNext(value,rest)=>CNext(L.delay(fn()=>f(L.force value)),cMap f rest))
 fun cBind f values=L.delay(fn()=>case L.force values of CEmpty=>CEmpty
   |CNext(value,rest)=>L.force(cAppend(f(L.force value))(cBind f rest)))
 fun cHead values=case L.force values of CNext(value,_)=>L.force value|CEmpty=>raise Empty
 fun cDefer f=L.delay(fn()=>L.force(f()))
 fun letter c=(c>= #"a"andalso c<= #"z")orelse(c>= #"A"andalso c<= #"Z")
 fun digit c=c>= #"0"andalso c<= #"9"
 fun letgit c=letter c orelse digit c orelse c= #"_"orelse c= #"'"
 fun realdigit c=digit c orelse List.exists(fn x=>x=c)[#"+",#"-",#"e",#"."]
 fun substring predicate reversed chars=L.delay(fn()=>case D.force chars of
      F.Nil=>(reverse reversed,empty())
     |F.Cons(c,rest)=>if predicate(D.force c)then L.force(substring predicate(F.cons(c,reversed))rest)
        else(reverse reversed,F.cons(c,rest)))
 fun splitText pair=D.delay(fn()=>let val(value,_)=L.force pair in D.force value end)
 fun splitRest pair=D.delay(fn()=>let val(_,rest)=L.force pair in D.force rest end)
 fun prefix chars literal=
   let fun loop _ []=true
         |loop chars(c::cs)=case D.force chars of F.Nil=>false
            |F.Cons(value,rest)=>D.force value=c andalso loop rest cs
   in loop chars(String.explode literal)end
 val operatorNames=["(:)","(++)","(+)","(-)","(--)","(*)","(/)","(~)"]
 fun firstOperator chars []=NONE
   |firstOperator chars(name::rest)=if prefix chars name then SOME name else firstOperator chars rest
 fun lexer chars=L.delay(fn()=>case D.force chars of F.Nil=>CEmpty
   |F.Cons(value,rest)=>
    let val c=D.force value
        fun emit token tail=CNext(L.delay(fn()=>token),lexer tail)
    in if c= #" "orelse c= #"\t"orelse c= #"\n"orelse c= #"\012"then L.force(lexer rest)
       else if c= #"|"andalso prefix chars"||"then L.force(lexer(dropWhile(fn c=>c<> #"\n")(F.drop 2 chars)))
       else if c= #"("then
         (case firstOperator chars operatorNames of SOME name=>emit(NAME(text name))(F.drop(String.size name)chars)
           |NONE=>emit(SYMB(text"("))rest)
       else if List.exists(fn x=>x=c)[#")",#",",#";",#"="]then emit(SYMB(text(String.str c)))rest
       else if c= #"#"then emit(NAME(text"#"))rest
       else if c= #"\""then
          let val scanned=substring(fn c=>c<> #"\"")(empty())rest
          in CNext(L.delay(fn()=>STR(splitText scanned)),cDefer(fn()=>lexer(tail(splitRest scanned))))end
       else if c= #"%"then
          let val scanned=substring letgit(empty())rest
          in CNext(L.delay(fn()=>PRAG(splitText scanned)),lexer(splitRest scanned))end
       else if letter c then
          let val scanned=substring letgit(one c)rest
          in CNext(L.delay(fn()=>NAME(splitText scanned)),lexer(splitRest scanned))end
       else if digit c then
          let val scanned=substring realdigit(one c)rest
          in CNext(L.delay(fn()=>NUMB(splitText scanned)),lexer(splitRest scanned))end
       else emit(ERR(append(text"illegal char ")(one c)))rest
    end)
 fun findPragma wanted reversed tokens=D.delay(fn()=>
   case L.force tokens of CEmpty=>D.force(reverse reversed)
    |CNext(value,rest)=>(case L.force value of PRAG name=>
       (case L.force rest of CNext(next,tail)=>(case L.force next of STR argument=>
           D.force(findPragma wanted(if equal wanted name then cons argument reversed else reversed)tail)
         |_=>D.force(findPragma wanted reversed rest))
        |CEmpty=>D.force(findPragma wanted reversed rest))
      |_=>D.force(findPragma wanted reversed rest)))
 fun dropPragma tokens=L.delay(fn()=>case L.force tokens of CEmpty=>CEmpty
   |CNext(value,rest)=>(case L.force value of PRAG _=>
        (case L.force rest of CNext(_,tail)=>L.force(dropPragma tail)|CEmpty=>CNext(value,dropPragma rest))
     |_=>CNext(value,dropPragma rest)))
 fun tokenOrder(NUMB _)=1|tokenOrder(NAME _)=2|tokenOrder(SYMB _)=3|tokenOrder(STR _)=4
   |tokenOrder(PRAG _)=5|tokenOrder(ERR _)=6|tokenOrder LAYOUT=7
 fun tokenText(NUMB value)=value|tokenText(NAME value)=value|tokenText(SYMB value)=value
   |tokenText(STR value)=value|tokenText(PRAG value)=value|tokenText(ERR value)=value
   |tokenText LAYOUT=empty()
 fun tokenCompare first last=
   let val order=tokenOrder first-tokenOrder last
   in if order=0 then compareChars(tokenText first)(tokenText last)else order end
