 type chars=char C.seq
 fun input source=C.fromList(String.explode source)
 fun charUncons values=case L.force values of C.Nil=>NONE|C.Cons(x,rest)=>SOME(L.force x,rest)
 fun charSpan predicate chars=case charUncons chars of NONE=>(C.empty(),C.empty())
   |SOME(c,rest)=>if predicate c then let val split=L.delay(fn()=>charSpan predicate rest)
       in(C.cons(L.delay(fn()=>c),C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
     else(C.empty(),chars)
 fun charsToName chars=F.defer(fn()=>case charUncons chars of NONE=>F.empty()
   |SOME(c,rest)=>F.cons(cell c,charsToName rest))
 fun prefixChars prefix chars=
   let fun loop [] chars=SOME chars|loop(c::cs)chars=case charUncons chars of
        SOME(d,rest)=>if c=d then loop cs rest else NONE|NONE=>NONE
   in loop(String.explode prefix)chars end
 fun token line text rest=C.cons(L.delay(fn()=>(line,text)),rest)
 val endTokens:token C.seq=C.fromList[(int 999999,name"$$$")]
 fun lex line chars=C.defer(fn()=>
   let fun ordinary()=case charUncons chars of NONE=>endTokens
         |SOME(c,rest)=>if c= #"{"then comment line rest
           else if c= #"\n"then lex(add line(int 1))rest
           else if c= #" "orelse c= #"\t"then lex line rest
           else if Char.isDigit c then let val(digits,tail)=charSpan Char.isDigit rest
             in token line(F.cons(cell c,charsToName digits))(lex line tail)end
           else if Char.isAlpha c then let val(identifier,tail)=charSpan
                  (fn c=>Char.isAlpha c orelse Char.isDigit c orelse c= #"_")rest
             in token line(F.cons(cell c,charsToName identifier))(lex line tail)end
           else token line(name(String.str c))(lex line rest)
       fun two()=case charUncons chars of NONE=>ordinary()|SOME(c,rest)=>
         case L.force rest of C.Nil=>ordinary()|C.Cons(d,tail)=>
           if not(List.exists(fn x=>x=c)[#"=",#">",#"<",#"-",#";"])then ordinary()
           else let val d=L.force d
           in if List.exists(fn s=>s=String.implode[c,d])["==",">=","<=","->",";;"]
              then token line(name(String.implode[c,d]))(lex line tail)else ordinary()end
   in case prefixChars"::="chars of SOME tail=>token line(name"::=")(lex line tail)|NONE=>two()end)
 and comment line chars=C.defer(fn()=>case charUncons chars of NONE=>lex line(C.empty())
   |SOME(c,rest)=>if c= #"}"then lex line rest else
      comment(if c= #"\n"then add line(int 1)else line)rest)
 fun failed result=case L.force result of PFail _=>true|POk _=>false
 fun parsedItem result=case L.force result of POk(value,_)=>value|_=>raise Match
 fun parsedRest result=case L.force result of PFail rest=>rest|POk(_,rest)=>rest
 fun paLiteral literal tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail(C.empty())
   |C.Cons(tok,rest)=>let val(_,text)=L.force tok
      in if equalName literal text then POk(literal,rest)else PFail tokens end)
 fun paAlts alternatives tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail(C.empty())
   |C.Cons(tok,_)=>let val(_,text)=L.force tok
       fun choose []=PFail(C.empty())
         |choose((predicate,parser)::rest)=if predicate text then L.force(parser tokens)else choose rest
     in choose alternatives end)
 fun paThen2 combine p q tokens=L.delay(fn()=>case L.force(p tokens)of PFail rest=>PFail rest
   |POk(a,rest)=>case L.force(q rest)of PFail rest=>PFail rest|POk(b,rest)=>POk(combine a b,rest))
 fun paThen3 combine p q r tokens=L.delay(fn()=>case L.force(p tokens)of PFail rest=>PFail rest
   |POk(a,rest)=>case L.force(q rest)of PFail rest=>PFail rest
     |POk(b,rest)=>case L.force(r rest)of PFail rest=>PFail rest
       |POk(c,rest)=>POk(combine a b c,rest))
 fun paThen4 combine p q r s tokens=L.delay(fn()=>case L.force(p tokens)of PFail rest=>PFail rest
   |POk(a,rest)=>case L.force(q rest)of PFail rest=>PFail rest
     |POk(b,rest)=>case L.force(r rest)of PFail rest=>PFail rest
       |POk(c,rest)=>case L.force(s rest)of PFail rest=>PFail rest
         |POk(d,rest)=>POk(combine a b c d,rest))
 fun paZeroOrMore parser tokens=L.delay(fn()=>case L.force(parser tokens)of
   PFail _=>POk(F.empty(),tokens)
  |POk(value,rest)=>case L.force(paZeroOrMore parser rest)of
     PFail _=>POk(singleton value,rest)
    |POk(values,rest)=>POk(F.cons(value,values),rest))
 fun paOneOrMore parser=paThen2(fn x=>fn xs=>F.cons(x,xs))parser(paZeroOrMore parser)
 fun paOneOrMoreSep parser separator tokens=L.delay(fn()=>case L.force(parser tokens)of
    PFail _=>PFail tokens
   |POk(value,rest)=>(case L.force(separator rest)of PFail _=>POk(singleton value,rest)
     |POk(_,after)=>case L.force(paOneOrMoreSep parser separator after)of
       PFail _=>POk(singleton value,rest)|POk(values,rest)=>POk(F.cons(value,values),rest)))
 fun paApply parser f tokens=L.delay(fn()=>case L.force(parser tokens)of
   PFail rest=>PFail rest|POk(value,rest)=>POk(f value,rest))
 fun paSatisfy predicate tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail(C.empty())
   |C.Cons(tok,rest)=>let val(_,text)=L.force tok
     in if predicate text then POk(text,rest)else PFail rest end)
 fun paEmpty value tokens=L.delay(fn()=>POk(value,tokens))
 fun literal s=paLiteral(name s)
 fun tokenIs s text=equalName(name s)text
 fun numericValue chars=
   let val digits=map(fn c=>int(Char.ord(force c)-48))(reverse chars)
       fun powers scale digits=F.defer(fn()=>case force digits of F.Nil=>F.empty()
         |F.Cons(d,rest)=>F.cons(multiply scale d,powers(multiply(int 10)scale)rest))
   in foldLeft add(int 0)(powers(int 1)digits)end
