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
   case L.force values of C.Nil=>closeBraces(List.length stack-1)99999 99999
    |C.Cons(first,remaining)=>(case L.force remaining of
       C.Nil=>C.cons(first,closeBraces(List.length stack-1)99998 99998)
      |C.Cons(second,tail)=>
        let val(l1,n1,w1,_)=L.force first val(l2,n2,w2,_)=L.force second
        in case stack of []=>raise Match
         |indent::rest=>
          if(w1=Lof orelse w1=Llet orelse w1=Lwhere)andalso w2<>Llbrace then
             C.cons(first,C.cons(token l1 n1 Llbrace(text"{"),C.cons(second,layout l2(n2::indent::rest)tail)))
          else if l1=line then C.cons(first,layout line stack remaining)
          else if n1>indent then C.cons(first,layout l1 stack remaining)
          else if n1=indent then C.cons(token l1 n1 Lsemi(text";"),C.cons(first,layout l1 stack remaining))
          else C.cons(token l1 n1 Lrbrace(text"}"),layout line rest values)
        end))
 fun main chars=layout 1[0](mapTokens keyword(lex 1 1 chars))
end
