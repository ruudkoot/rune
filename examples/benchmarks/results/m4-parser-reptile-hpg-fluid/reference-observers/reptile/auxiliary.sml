 fun concmap3 f xs ys zs=F.defer(fn()=>case D.force xs of F.Nil=>F.empty()
   |F.Cons(x,xs)=>(case D.force ys of F.Nil=>F.empty()
     |F.Cons(y,ys)=>(case D.force zs of F.Nil=>F.empty()
       |F.Cons(z,zs)=>F.append(f x y z)(concmap3 f xs ys zs))))
 fun drawingLine entry=F.defer(fn()=>let val(value,_)=D.force entry in value end)
 fun drawingCircles entry=F.defer(fn()=>let val(_,value)=D.force entry in value end)
 fun display entries=concmap3 place(ints[624,624,624,624,724,724,724,724])
     (ints[676,776,876,976,676,776,876,976])(map(fn entry=>F.defer(fn()=>let val(_,value)=D.force entry in value end))entries)
 fun orient size(n:integer)values=F.defer(fn()=>case D.force n of
      0w0=>singleton(ints[0,0,0,0])|0w1=>values
     |0w2=>rotatecw size values|0w3=>rotatecw size(rotatecw size values)
     |0w4=>antirotate size values|0w5=>tbinvert size values
     |0w6=>tbinvert size(rotatecw size values)|0w7=>lrinvert size values
     |0w8=>lrinvert size(rotatecw size values)|_=>raise Match)
 val pixdist=int 10
 fun between n1 n2 n=le n1 n andalso ge n2 n orelse ge n1 n andalso le n2 n
 fun online values xp yp=
   let val(x0,y0,x1,y1)=list4 values
   in if eq y0 y1 then between x0 x1 xp andalso lt(absolute(sub y0 yp))pixdist
      else if eq x0 x1 then between y0 y1 yp andalso lt(absolute(sub x0 xp))pixdist
      else let
       val k1=rdiv(torat(sub x0 x1))(torat(sub y0 y1))
       val k0=rsub(torat x0)(rmul k1(torat y0))
       val xprime=radd k0(rmul k1(torat yp))
       val yprime=rdiv(rsub(torat xp)k0)k1
       val a2=add(square(diff x0 x1))(square(diff y0 y1))
       val b2=add(square(diff x1 xp))(square(diff y1 yp))
       val c2=add(square(diff x0 xp))(square(diff y0 yp))
       val dx=rabs(rsub(torat xp)xprime)
       val dy=rabs(rsub(torat yp)yprime)
      in le b2(add a2 c2)andalso le c2(add a2 b2)andalso lt(intval(rmin dx dy))pixdist end end
 fun eqIntegers left right=case(D.force left,D.force right)of(F.Nil,F.Nil)=>true
   |(F.Cons(a,as'),F.Cons(b,bs))=>eq a b andalso eqIntegers as' bs|_=>false
 fun eqDrawingEntry first second=
   let val(a,b)=D.force first val(c,d)=D.force second
   in eqIntegers a c andalso eqIntegers b d end
 fun remove1 equal values wanted=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>if equal wanted value then rest else F.cons(value,remove1 equal rest wanted))
 fun listremove1 equal values remove=
   let fun loop result values=case D.force values of F.Nil=>result
         |F.Cons(value,rest)=>loop(F.defer(fn()=>remove1 equal result value))rest
   in F.defer(fn()=>loop values remove)end
 fun onedge n=eq n dpxyorig orelse eq n(add dpxyorig(mul(sub dpxynum(int 1))dpxygap))
 fun nearest n=D.delay(fn()=>
   let val n1=add dpxyorig(mul(divide(sub n dpxyorig)dpxygap)dpxygap)
       val n2=add n1 dpxygap
   in D.force(if lt(sub n n1)(sub n2 n)then n1 else n2)end)
 fun nearx x=nearest(sub x(int 4))
 fun neary y=nearest(sub y(int 5))
 fun numassoc n=D.delay(fn()=>let val n1=divide(sub n dpxyorig)dpxygap
   in D.force(if le n1(int 9)then n1 else sub(int 18)n1)end)
 fun circ6 x y=circle(F.cons(x,F.cons(y,ints[6])))
 fun sympat n=F.cons(n,F.cons(sub(int 400)n,F.cons(int 380,F.cons(int 380,
   F.cons(sub(int 400)n,F.cons(n,ints[20,20]))))))
 fun zipWith f xs ys=F.defer(fn()=>case D.force xs of F.Nil=>F.empty()
   |F.Cons(x,xs)=>(case D.force ys of F.Nil=>F.empty()
     |F.Cons(y,ys)=>F.cons(D.delay(fn()=>D.force(f x y)),zipWith f xs ys)))
 fun symcircs n=flatMap(fn value=>value)(zipWith circ6(sympat n)(reverse(sympat n)))
 fun circsym xn yn=D.delay(fn()=>if onedge xn then(symcircs yn,singleton(numassoc yn))
   else if onedge yn then(symcircs xn,singleton(numassoc xn))else(text"",F.empty()))
 fun cs values=D.delay(fn()=>let val(x0,y0,x1,y1)=list4 values
     val first=circsym x0 y0 val second=circsym x1 y1
     val circles0=F.defer(fn()=> #1(D.force first))val ids0=F.defer(fn()=> #2(D.force first))
     val circles1=F.defer(fn()=> #1(D.force second))val ids1=F.defer(fn()=> #2(D.force second))
   in(pieces[line values,circles0,circles1],F.append ids0 ids1)end)
 fun decirc n=undo(symcircs(add(mul n dpxygap)dpxyorig))
 fun wscale n=divide(sub n dpxyorig)(int 5)
 fun wwscale n=divide(sub n dpxyorig)(int 10)
 fun wline values=line(mapx(fn x=>add x picxorig)(mapy(fn y=>add y picyorig)(map wscale values)))
 fun showoris values n=F.defer(fn()=>let val(x,y,_,_)=list4(picbox n)
   in place x y(orient xymax n(map(map wscale)values))end)
 fun deline values point=D.delay(fn()=>
   let val(px,py)=list2 point
       fun loop entries=case D.force entries of F.Nil=>(text"",values)
         |F.Cons(entry,rest)=>
           let val(thisline,thesecircs)=D.force entry
               val restcircs=listremove1 eq(flatMap drawingCircles values)thesecircs
               val decircs=flatMap decirc(listremove1 eq restcircs thesecircs)
           in if online thisline px py then(pieces[undraw thisline,undo(wline thisline),decircs],
                remove1 eqDrawingEntry values entry)else loop rest end
   in loop values end)
