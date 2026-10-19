 fun nextoct n=modulo(add n(int 1))(int 8)
 fun nop value=D.delay(fn()=>let val(a,b)=D.force value
   in if eq b(int 7)then(nextoct a,int 0)else(a,nextoct b)end)
 fun indices value=C.cons(L.delay(fn()=>D.force value),C.defer(fn()=>indices(nop value)))
 fun takeControl n values=F.defer(fn()=>if n<=0 then F.empty()
   else case L.force values of C.Nil=>F.empty()|C.Cons(value,rest)=>F.cons(D.delay(fn()=>L.force value),takeControl(n-1)rest))
 val alistind=takeControl 64(indices(pair(int 0)(int 0)))
 val initalist=map(fn key=>pair key(int 0))alistind
 fun mark n=F.defer(fn()=>if eq n(int 0)then text""
   else let val(x,y,width,height)=list4(picbox n)
     in rectangle(F.cons(sub x(int 3),F.cons(sub y(int 3),
        F.cons(add(add x width)(int 3),singleton(add(add y height)(int 3))))))end)
 fun unmark n=undo(mark n)
 fun tlx x=add tpxorig(mul(divide(sub x tpxorig)tpxygap)tpxygap)
 fun tly y=add tpyorig(mul(divide(sub y tpyorig)tpxygap)tpxygap)
 fun tlidx x=divide(sub x tpxorig)tpxygap
 fun tlidy y=divide(sub y tpyorig)tpxygap
 fun sqas x y=F.cons(tlx x,singleton(tly y))
 fun sqid values=D.delay(fn()=>let val(x,y)=list2 values in(tlidy y,tlidx x)end)
 fun squas value=F.defer(fn()=>let val(a,b)=D.force value
   in F.cons(add tpxorig(mul b tpxygap),singleton(add tpyorig(mul a tpxygap)))end)
 fun btlocate values=F.defer(fn()=>let val(x,y)=list2 values
   in if inbigtile x y then sqas x y else ints[0,0]end)
 fun put values coords=F.defer(fn()=>let val(x,y)=list2 values in place x y coords end)
 fun ineights values=F.defer(fn()=>if null values then F.empty()
   else F.cons(F.take 8 values,ineights(F.drop 8 values)))
 fun rot n=D.delay(fn()=>case D.force n of
      0w0=>0w0|0w4=>0w1|0w8=>0w7|0w7=>0w6|0w6=>0w5|0w5=>0w8|word=>W.+(word,0w1))
 fun turn n=D.delay(fn()=>D.force(if eq n(int 0)then int 0
   else if eq n(int 4)then int 8 else modulo(add n(int 4))(int 8)))
 val inv=turn
 fun inbox values=D.delay(fn()=>let val(xp,yp)=list2 values
     fun loop n=if gt n(int 8)then int 0
       else let val(x,y,width,height)=list4(picbox n)
            in if inrect x y width height xp yp then n else loop(add n(int 1))end
   in D.force(loop(int 1))end)
 fun tpatformat rows=F.defer(fn()=>case D.force rows of F.Nil=>text""
   |F.Cons(row,rest)=>
     let fun formline values=F.defer(fn()=>case D.force values of F.Nil=>raise Match
           |F.Cons(n,ns)=>if null ns then showInt n else pieces[showInt n,text" ",formline ns])
     in pieces[formline row,text"\n",tpatformat rest]end)
 fun pam f values arg=map(fn x=>f x arg)values
 fun eqKey first second=let val(a,b)=D.force first val(c,d)=D.force second in eq a c andalso eq b d end
 fun newas key value entries=F.defer(fn()=>case D.force entries of F.Nil=>singleton(pair key value)
   |F.Cons(entry,rest)=>let val(oldKey,_)=D.force entry
      in if eqKey oldKey key then F.cons(pair key value,rest)else F.cons(entry,newas key value rest)end)
 fun assoc key entries=D.delay(fn()=>case D.force entries of F.Nil=>raise Match
   |F.Cons(entry,rest)=>let val(oldKey,value)=D.force entry
       in D.force(if eqKey key oldKey then value else assoc key rest)end)
 fun repeatControl value=
   let val holder=ref NONE
       val head=L.delay(fn()=>D.force value)
       val root=L.delay(fn()=>C.Cons(head,case !holder of SOME root=>root|NONE=>raise Fail"repeat knot"))
       val _=holder:=SOME root
   in root end
 fun takeMachine count values=F.defer(fn()=>if le count(int 0)then F.empty()
   else case L.force values of C.Nil=>F.empty()
    |C.Cons(value,rest)=>F.cons(D.delay(fn()=>L.force value),takeMachine(sub count(int 1))rest))
 fun concrep count value=flatMap(fn value=>value)(takeMachine count(repeatControl value))
