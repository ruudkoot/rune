functor BenchTransformFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 type text=char F.seq
 datatype token=NUMB of text|NAME of text|SYMB of text|STR of text|PRAG of text|ERR of text|LAYOUT
 datatype defNode=Caf of text F.seq*expr|Def of text*text F.seq*expr*whereExpr
 and whereNode=Where of program|NoWhere
 and exprNode=Tail of int D.t*expr|Cons of int D.t*expr*expr
   |Map of int D.t*text*expr F.seq|Maps of int D.t*text*text*expr*expr F.seq
   |Ap of text*expr F.seq|Tuple of expr F.seq|Var of text|Lit of text
 withtype def=defNode D.t
 and whereExpr=whereNode D.t
 and expr=exprNode D.t
 and program=defNode D.t F.seq
 type quad=text*text F.seq*text*program
 fun text s=F.fromList(String.explode s)
 fun list xs=F.fromList xs
 fun empty()=F.empty()
 fun one x=F.cons(D.delay(fn()=>x),F.empty())
 fun cons x xs=F.cons(D.delay(fn()=>x),xs)
 fun number cell=D.delay(fn()=>D.force(text(String.map(fn #"~"=> #"-"|c=>c)(Int.toString(D.force cell)))))
 fun append xs ys=F.append xs ys
 fun concat texts=D.delay(fn()=>case D.force texts of F.Nil=>F.Nil
   |F.Cons(x,rest)=>D.force(append(D.force x)(concat rest)))
 fun map f xs=F.map f xs
 fun reverse xs=F.foldl(fn acc=>fn x=>cons x acc)(empty())xs
 fun head xs=case D.force xs of F.Cons(x,_)=>D.force x|F.Nil=>raise Empty
 fun tail xs=case D.force xs of F.Cons(_,rest)=>rest|F.Nil=>raise Empty
 fun null xs=case D.force xs of F.Nil=>true|_=>false
 fun foldr f initial xs=D.delay(fn()=>case D.force xs of F.Nil=>D.force initial
   |F.Cons(x,rest)=>D.force(f x(foldr f initial rest)))
 fun filter p xs=F.filter p xs
 fun compareChars xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>0
   |(F.Nil,_)=> ~1|(_,F.Nil)=>1
   |(F.Cons(a,rest),F.Cons(b,tail))=>
       let val order=Char.ord(D.force a)-Char.ord(D.force b)
       in if order=0 then compareChars rest tail else order end
 fun equal xs ys=compareChars xs ys=0
 fun member cmp xs value=case D.force xs of F.Nil=>false
   |F.Cons(x,rest)=>cmp value(D.force x)=0 orelse member cmp rest value
 fun all p xs=case D.force xs of F.Nil=>true
   |F.Cons(x,rest)=>p(D.force x)andalso all p rest
 fun takeWhile p xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if p(D.force x)then F.Cons(x,takeWhile p rest)else F.Nil)
 fun dropWhile p xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if p(D.force x)then D.force(dropWhile p rest)else F.Cons(x,rest))
 fun fromInt n=D.delay(fn()=>n)
 fun caf vars expr=D.delay(fn()=>Caf(vars,expr))
 fun def name vars expr whereExpr=D.delay(fn()=>Def(name,vars,expr,whereExpr))
 fun whereExpr program=D.delay(fn()=>Where program)
 fun noWhere()=D.delay(fn()=>NoWhere)
 fun var name=D.delay(fn()=>Var name)
 fun lit value=D.delay(fn()=>Lit value)
 fun tuple values=D.delay(fn()=>Tuple values)
 fun ap name values=D.delay(fn()=>Ap(name,values))
 fun tailExpr label expr=D.delay(fn()=>Tail(label,expr))
 fun consExpr label state expr=D.delay(fn()=>Cons(label,state,expr))
 fun mapExpr label name values=D.delay(fn()=>Map(label,name,values))
 fun mapsExpr label first last state values=D.delay(fn()=>Maps(label,first,last,state,values))
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
end
