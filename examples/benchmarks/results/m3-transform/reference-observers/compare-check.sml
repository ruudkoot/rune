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
 fun listCompare cmp xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>0
   |(F.Nil,_)=> ~1|(_,F.Nil)=>1
   |(F.Cons(a,rest),F.Cons(b,tail))=>
      let val order=cmp(D.force a)(D.force b)
      in if order=0 then listCompare cmp rest tail else order end
 fun combine []=0|combine(first::rest)=let val n=first()in if n=0 then combine rest else n end
 fun exprOrder(Tail _)=1|exprOrder(Cons _)=2|exprOrder(Map _)=3|exprOrder(Maps _)=4
   |exprOrder(Ap _)=5|exprOrder(Tuple _)=6|exprOrder(Var _)=7|exprOrder(Lit _)=8
 fun intCompare(a:int D.t)(b:int D.t)=D.force a-D.force b
 fun compareExpr x y=
   let val a=D.force x val b=D.force y
       val order=exprOrder a-exprOrder b
   in if order<>0 then order else case(a,b)of
      (Tail(p,e),Tail(q,f))=>combine[fn()=>intCompare p q,fn()=>compareExpr e f]
     |(Cons(p,s,e),Cons(q,t,f))=>combine[fn()=>intCompare p q,fn()=>compareExpr s t,fn()=>compareExpr e f]
     |(Map(p,f,args),Map(q,g,args'))=>combine[fn()=>intCompare p q,fn()=>compareChars f g,fn()=>listCompare compareExpr args args']
     |(Maps(p,f,g,s,args),Maps(q,f',g',s',args'))=>combine[
         fn()=>intCompare p q,fn()=>compareChars f f',fn()=>compareChars g g',
         fn()=>compareExpr s s',fn()=>listCompare compareExpr args args']
     |(Ap(f,args),Ap(g,args'))=>combine[fn()=>compareChars f g,fn()=>listCompare compareExpr args args']
     |(Tuple args,Tuple args')=>listCompare compareExpr args args'
     |(Var a,Var b)=>compareChars a b
     |(Lit a,Lit b)=>compareChars a b
     |_=>raise Fail"transform expression comparison invariant"end
 fun compareDef x y=case(D.force x,D.force y)of
      (Caf(args,e),Caf(args',e'))=>combine[fn()=>listCompare compareChars args args',fn()=>compareExpr e e']
     |(Caf _,Def _)=> ~1
     |(Def(f,args,e,w),Def(g,args',e',w'))=>combine[fn()=>compareChars f g,
        fn()=>listCompare compareChars args args',fn()=>compareExpr e e',fn()=>compareWhere w w']
     |(Def _,Caf _)=>1
 and compareWhere x y=case(D.force x,D.force y)of
      (Where a,Where b)=>listCompare compareDef a b|(Where _,NoWhere)=> ~1
     |(NoWhere,NoWhere)=>0|(NoWhere,Where _)=>1
 fun merge unique cmp xs ys=D.delay(fn()=>case D.force xs of F.Nil=>D.force ys
   |F.Cons(a,rest)=>(case D.force ys of F.Nil=>F.Cons(a,rest)
      |F.Cons(b,tail)=>
       let val order=cmp(D.force a)(D.force b)
       in if order<0 orelse(order=0 andalso not unique)then F.Cons(a,merge unique cmp rest ys)
          else if order=0 then F.Cons(a,merge unique cmp rest tail)
          else F.Cons(b,merge unique cmp xs tail)end))
 fun sort unique cmp xs=D.delay(fn()=>
   let val size=F.length xs val middle=size div 2
   in if size<=1 then D.force xs else D.force(merge unique cmp(sort unique cmp(F.take middle xs))(sort unique cmp(F.drop middle xs)))end)
 fun removeOne cmp value xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if cmp(D.force x)(D.force value)=0 then D.force rest
      else F.Cons(x,removeOne cmp value rest))
 fun remove cmp xs ys=D.delay(fn()=>case D.force ys of F.Nil=>D.force xs
   |F.Cons(y,rest)=>D.force(remove cmp(removeOne cmp y xs)rest))
 fun uniqueNames names=sort true compareChars names
 fun uniqueDefs defs=sort true compareDef defs
 fun removeNames names removed=remove compareChars names removed
 fun removeDefs defs removed=remove compareDef defs removed
end
