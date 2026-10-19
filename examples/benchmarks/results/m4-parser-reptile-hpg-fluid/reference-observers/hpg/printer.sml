 structure B=struct
   type builder=text->text
   fun id rest=rest
   fun literal s rest=append(text s)rest
   fun cat a b rest=a(C.defer(fn()=>b rest))
   fun pieces []=id|pieces(x::xs)=cat x(pieces xs)
   fun delayed f rest=C.defer(fn()=>f()rest)
   fun bracket b=pieces[literal"(",b,literal")"]
   fun output b=b(C.empty())
 end
 fun nameText values=C.defer(fn()=>case force values of F.Nil=>C.empty()
   |F.Cons(c,rest)=>C.cons(L.delay(fn()=>force c),nameText rest))
 fun showName name tail=C.append(nameText(force name))tail
 fun sep separator printer values=B.delayed(fn()=>
   case force values of F.Nil=>B.id|F.Cons(x,rest)=>
     B.cat(printer x)(B.delayed(fn()=>if null rest then B.id
       else B.cat(B.literal separator)(sep separator printer rest))))
 fun showNumber d n=B.delayed(fn()=>let val value=force n
   val shown=B.literal(number value)
   in if value<0 andalso d>6 then B.bracket shown else shown end)
 fun showKind kind=B.literal(case kind of IntType=>"Int"|IntegerType=>"Integer"|FloatType=>"Float"|DoubleType=>"Double")
 fun showBase bt=case bt of NumType kind=>showKind kind|BoolType=>B.literal"Bool"|CharType=>B.literal"Char"
 fun showArg d arg=B.delayed(fn()=>case force arg of NameType name=>showName name
   |BasicType bt=>showBase(force bt)
   |ListType id=>B.pieces[B.literal"[",showArg 0 id,B.literal"]"]
   |TupleType ids=>B.pieces[B.literal"(",sep ", "(showArg 0)ids,B.literal")"]
   |ArrayType(a,b)=>let val body=B.pieces[B.literal"Array ",showArg 10 a,B.literal" ",showArg 10 b]
     in if d>=10 then B.bracket body else body end)
 fun showTypeDecl pair=B.delayed(fn()=>let val(name,variants)=force pair
     fun variant p=B.delayed(fn()=>let val(name,args)=force p
       in B.pieces[showName name,B.literal" ",sep " "(showArg 10)args]end)
   in B.pieces[B.literal"data ",showName name,B.literal" = ",sep " | " variant variants,
        B.literal" deriving (Eq)"]end)
 val asciiNames=["NUL","SOH","STX","ETX","EOT","ENQ","ACK","BEL","BS","HT","LF","VT",
   "FF","CR","SO","SI","DLE","DC1","DC2","DC3","DC4","NAK","SYN","ETB","CAN","EM",
   "SUB","ESC","FS","GS","RS","US","SP"]
 fun charLiteral c=let val n=Char.ord c
    val value=case c of #"'"=>"\\'"| #"\\"=>"\\\\"| #"\a"=>"\\a"| #"\b"=>"\\b"
       | #"\f"=>"\\f"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"| #"\v"=>"\\v"
       |_=>if n=127 then "\\DEL"else if n<32 then "\\"^List.nth(asciiNames,n)else String.str c
   in "'"^value^"'"end
 fun showValue d v=B.delayed(fn()=>case force v of
   NumVal(kind,n)=>(case kind of IntType=>showNumber d n|IntegerType=>showNumber d n
      |_=>let val value=force n val b=B.literal(number value^".0")
          in if d>6 andalso value<0 then B.bracket b else b end)
  |BoolVal b=>B.literal(if force b then "True"else"False")
  |CharVal c=>B.literal(charLiteral(force c))
  |ListVal vs=>B.pieces[B.literal"[",sep ", "(showValue 0)vs,B.literal"]"]
  |TupleVal vs=>B.pieces[B.literal"(",sep ", "(showValue 0)vs,B.literal")"]
  |TaggedVal(name,vs)=>let val b=B.pieces[showName name,B.literal" ",sep " "(showValue 10)vs]
       in if d>=10 then B.bracket b else b end
  |ArrayVal((lo,hi),assocs)=>let
       fun association p=B.delayed(fn()=>let val(a,b)=force p
         in B.pieces[B.literal"(",showValue 0 a,B.literal",",showValue 0 b,B.literal")"]end)
       val b=B.pieces[B.literal"array ",showValue 10(tuple(F.cons(lo,F.cons(hi,F.empty())))),
         B.literal" [",sep ","association assocs,B.literal"]"]
     in if d>=10 then B.bracket b else b end)
 fun showValDecl pair=B.delayed(fn()=>let val(name,value)=force pair
   in B.pieces[showName name,B.literal" = ",showValue 0 value]end)
 fun showExpression d e=B.delayed(fn()=>case force e of
   ApplyExp(a,b)=>let val body=B.pieces[showExpression 10 a,B.literal" ",showExpression 11 b]
       in if d>10 then B.bracket body else body end
  |IdExp name=>let val body=showName name
          val first=case force(force name)of F.Nil=>raise Match|F.Cons(c,_)=>force c
      in if not(Char.isAlpha first)then B.bracket body else body end
  |ValExp v=>showValue d v
  |TaggedExp(name,es)=>let val body=B.pieces[showName name,B.literal" ",sep " "(showExpression 11)es]
     in if d>10 then B.bracket body else body end
  |ListExp es=>B.pieces[B.literal"[",sep ", "(showExpression 0)es,B.literal"]"]
  |TupleExp es=>B.pieces[B.literal"(",sep ", "(showExpression 0)es,B.literal")"]
  |LambdaExp(name,e)=>B.pieces[B.literal"(\\",showName name,B.literal" -> ",showExpression 0 e,B.literal")"]
  |ArrayExp(a,b)=>let val body=B.pieces[B.literal"array ",showExpression 11 a,B.literal" ",showExpression 11 b]
     in if d>10 then B.bracket body else body end)
 (* Source split_num returns both halves lazily; preserve the shared split. *)
 fun splitNum n chars=if n=0 then(C.empty(),chars)else
   case BenchNeed.force chars of C.Nil=>(C.empty(),C.empty())
    |C.Cons(c,rest)=>if L.force c= #"\n"then(C.empty(),C.cons(L.delay(fn()=> #" "),rest))
     else let val split=L.delay(fn()=>splitNum(n-1)rest)
          in(C.cons(c,C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
 fun span predicate chars=case BenchNeed.force chars of C.Nil=>(C.empty(),C.empty())
   |C.Cons(c,rest)=>if predicate(L.force c)then
       let val split=L.delay(fn()=>span predicate rest)
       in(C.cons(c,C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
     else(C.empty(),chars)
 fun dropWhile predicate chars=C.defer(fn()=>case BenchNeed.force chars of C.Nil=>C.empty()
    |C.Cons(c,rest)=>if predicate(L.force c)then dropWhile predicate rest else chars)
 fun splitStr n chars=C.defer(fn()=>case BenchNeed.force chars of C.Nil=>C.empty()
    |_=>let val(start,rest1)=splitNum n chars val(next,rest)=span(not o Char.isSpace)rest1
      in append start(append next(append(text"\n")(splitStr n(dropWhile Char.isSpace rest))))end)
