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
end
