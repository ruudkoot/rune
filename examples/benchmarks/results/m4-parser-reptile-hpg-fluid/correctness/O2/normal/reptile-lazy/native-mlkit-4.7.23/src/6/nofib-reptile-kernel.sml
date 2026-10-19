functor BenchReptileFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure W=Word64
 structure S=BenchSigned64
 type integer=W.word D.t
 type text=char F.seq
 type integers=W.word F.seq
 type segments=W.word F.node F.seq
 type drawing=(integers*integers)F.seq
 type association=((integer*integer)D.t*integer)F.seq
 type state=(drawing*integer*association)L.delay
 fun int n=D.delay(fn()=>W.fromInt n)
 fun text s=F.fromList(String.explode s)
 fun string s=String.implode(F.toList s)
 fun number value=
   let val word=D.force value val magnitude=W.toLargeInt word
       val signed=if S.negative word then magnitude-18446744073709551616 else magnitude
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString signed)end
 fun showInt value=F.defer(fn()=>text(number value))
 fun add a b=D.delay(fn()=>W.+(D.force a,D.force b))
 fun sub a b=D.delay(fn()=>W.-(D.force a,D.force b))
 fun mul a b=D.delay(fn()=>W.*(D.force a,D.force b))
 fun divide a b=D.delay(fn()=>S.divide(D.force a,D.force b))
 fun modulo a b=D.delay(fn()=>S.modulo(D.force a,D.force b))
 fun negative a=D.delay(fn()=>S.negate(D.force a))
 fun absolute a=D.delay(fn()=>S.magnitude(D.force a))
 fun eq a b=D.force a=D.force b
 fun lt a b=S.less(D.force a,D.force b)
 fun le a b=S.leq(D.force a,D.force b)
 fun gt a b=lt b a
 fun ge a b=le b a
 fun singleton value=F.cons(value,F.empty())
 fun pair a b=D.delay(fn()=>(a,b))
 fun ints values=List.foldr(fn(n,rest)=>F.cons(int n,rest))(F.empty())values
 fun map f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.cons(D.delay(fn()=>D.force(f value)),map f rest))
 fun flatMap f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.append(f value)(flatMap f rest))
 fun foldr f initial values=D.delay(fn()=>case D.force values of F.Nil=>D.force initial
   |F.Cons(value,rest)=>D.force(f value(foldr f initial rest)))
 fun head values=case D.force values of F.Cons(value,_)=>value|F.Nil=>raise Fail"Prelude.head: empty list"
 fun tail values=F.defer(fn()=>case D.force values of F.Cons(_,rest)=>rest|F.Nil=>raise Fail"Prelude.tail: empty list")
 fun null values=case D.force values of F.Nil=>true|_=>false
 fun length values=D.delay(fn()=>
   let fun loop n values=case D.force values of F.Nil=>n|F.Cons(_,rest)=>loop(n+1)rest
   in W.fromInt(loop 0 values)end)
 fun reverse values=F.defer(fn()=>
   let fun loop values result=case D.force values of F.Nil=>result|F.Cons(value,rest)=>loop rest(F.cons(value,result))
   in loop values(F.empty())end)
 fun list4 values=
   let val a=head values val values=tail values val b=head values
       val values=tail values val c=head values val values=tail values val d=head values
   in if null(tail values)then(a,b,c,d)else raise Match end
 fun list2 values=
   let val a=head values val rest=tail values val b=head rest
   in if null(tail rest)then(a,b)else raise Match end
 fun square n=mul n n
 fun diff a b=D.delay(fn()=>D.force(if gt a b then sub a b else sub b a))
 fun bcroot n=D.delay(fn()=>
   let fun root a b=if ge(add a(int 1))b then b
         else let val m=divide(add a b)(int 2)val s=mul m m
              in if lt s n then root m b else if lt n s then root a m else m end
   in D.force(root(int 0)n)end)
 fun norm rational=D.delay(fn()=>
   let val(x,y)=D.force rational
       val u=D.delay(fn()=>D.force(if gt y(int 0)then x else negative x))
       val v=absolute y
       fun gcd n1 n2=D.delay(fn()=>
         if eq n1(int 0)then D.force n2 else if eq n2(int 0)then D.force n1
         else D.force(if lt n1 n2 then gcd n1(modulo n2 n1)else gcd(modulo n1 n2)n2))
       val d=gcd(absolute u)v
   in(divide u d,divide v d)end)
 fun radd first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(add(mul x v)(mul u y))(mul y v)))end)
 fun rsub first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(sub(mul x v)(mul u y))(mul y v)))end)
 fun rmul first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(mul x u)(mul y v)))end)
 fun rdiv first second=D.delay(fn()=>
   let val(x,y)=D.force first val(u,v)=D.force second
   in D.force(norm(pair(mul x v)(mul y u)))end)
 fun rmin first second=D.delay(fn()=>
   let val(a,_)=D.force(rsub first second)
   in D.force(if gt a(int 0)then second else first)end)
 fun rabs rational=D.delay(fn()=>let val(x,y)=D.force rational
   in(if lt x(int 0)then negative x else x,y)end)
 fun intval rational=D.delay(fn()=>let val(x,y)=D.force rational in D.force(divide x y)end)
 fun torat n=pair n(int 1)
 fun show_rat rational=F.defer(fn()=>let val(x,y)=D.force rational
   in F.append(showInt x)(F.append(text"/")(showInt y))end)
 fun escom suffix numbers=F.cons(D.delay(fn()=>Char.chr 27),
   foldr(fn n=>fn rest=>F.defer(fn()=>if null rest then F.append(showInt n)suffix
      else F.append(showInt n)(F.cons(D.delay(fn()=> #","),rest))))(text"")numbers)
 val aligntext=text"\027l"
 fun bitcopy args=escom(text"b")args
 fun circle args=escom(text"o")args
 val clear=text"\012"
 fun mapevent event=D.delay(fn()=>D.force(if eq event(int 3)orelse eq event(int 4)then sub(int 2)event else event))
 fun clearevent event=escom(text"e")(singleton(mapevent event))
 fun clearmode mode=escom(text"s")(singleton mode)
 fun destroywin n=escom(text",OZ")(singleton n)
 fun dragcircle values=F.defer(fn()=>
   let val(x1,y1,x2,y2)=list4 values
       val r=bcroot(add(square(diff x1 x2))(square(diff y1 y2)))
   in circle(F.cons(x1,F.cons(y1,singleton r)))end)
 val dragline=text"%l\n"
 val dragrect=text"%r\n"
 fun font x=escom(text"F")(singleton x)
 fun func mode=escom(text"b")(singleton mode)
 fun go args=escom(text"g")args
 fun highlight args=escom(text"H")args
 fun line args=escom(text"l")args
 fun newwin args=escom(text"Z")args
 fun rcircle r=escom(text"o")(singleton r)
 fun selectwin n=escom(text"Z")(singleton n)
 fun setevent event value=escom(F.append(text"e")value)(F.cons(mapevent event,singleton(length value)))
 fun setmode mode=escom(text"S")(singleton mode)
 fun shapewindow args=escom(text"W")args
 val standend=text"\027,n"
 val standout=text"\027i"
 fun stringto win x y value=escom(F.append(text".")value)
   (F.cons(win,F.cons(x,F.cons(y,singleton(length value)))))
 fun textregion args=escom(text"t")args
 val textreset=text"\027t"
 fun gowin n=F.append(selectwin n)(F.append(setmode(int 7))(setmode(int 8)))
 fun rectangle values=F.defer(fn()=>
   let val(x1,y1,x2,y2)=list4 values
       fun segment a b c d=F.cons(a,F.cons(b,F.cons(c,singleton d)))
   in F.append(line(segment x1 y1 x2 y1))
      (F.append(line(segment x2 y1 x2 y2))
      (F.append(line(segment x1 y1 x1 y2))(line(segment x1 y2 x2 y2))))end)
 fun fillrect values=F.defer(fn()=>
   let val(x0,y0,x1,y1)=list4 values
       val m=D.delay(fn()=>D.force(if le x0 x1 then x0 else x1))
       fun vline n=line(F.cons(n,F.cons(y0,F.cons(n,singleton y1))))
       fun shade n=F.defer(fn()=>if eq n(int 0)then vline m
          else F.append(vline(add m n))(shade(sub n(int 1))))
   in shade(diff x0 x1)end)
 fun squ n x y=rectangle(F.cons(x,F.cons(y,F.cons(add x n,singleton(add y n)))))
 fun circ n x y=circle(F.cons(x,F.cons(y,singleton n)))
 fun drawdot x y=fillrect(F.cons(sub x(int 1),F.cons(sub y(int 1),F.cons(add x(int 1),singleton(add y(int 1))))))
 fun undo value=F.append(func(int 0))(F.append value(func(int 15)))
 fun undraw value=undo(line value)
 fun drawlines values=flatMap line values
 fun allpairs f xs ys=F.defer(fn()=>case D.force xs of F.Nil=>F.empty()
    |F.Cons(x,rest)=>if null ys then F.empty()else F.append(map(f x)ys)(allpairs f rest ys))
 (* The unbounded grid producer remains a memoized control stream in both
  * finite policies. Only its selected finite prefix enters the workload. *)
 structure C=BenchIdaFiniteFn(BenchNeed)
 fun gridlist origin gap count=
   let fun produce n=C.cons(L.delay(fn()=>D.force n),C.defer(fn()=>produce(add n gap)))
       fun take n values=F.defer(fn()=>if eq n(int 0)orelse lt n(int 0)then F.empty()
         else case L.force values of C.Nil=>F.empty()
           |C.Cons(value,rest)=>F.cons(D.delay(fn()=>L.force value),take(sub n(int 1))rest))
   in take count(produce origin)end
 fun grid xorigin yorigin xgap ygap xlength ylength draw=
   flatMap(fn value=>value)
      (allpairs(fn x=>fn y=>D.delay(fn()=>D.force(draw x y)))
        (gridlist xorigin xgap xlength)(gridlist yorigin ygap ylength))
 fun swapxy values=F.defer(fn()=>
   let val(x1,y1,x2,y2)=list4 values in F.cons(y1,F.cons(x1,F.cons(y2,singleton x2)))end)
 fun mapx f values=F.defer(fn()=>
   let val(x1,y1,x2,y2)=list4 values in F.cons(f x1,F.cons(y1,F.cons(f x2,singleton y2)))end)
 fun mapy f values=F.defer(fn()=>
   let val(x1,y1,x2,y2)=list4 values in F.cons(x1,F.cons(f y1,F.cons(x2,singleton(f y2))))end)
 fun toright distance values=map(mapx(add distance))values
 fun down distance values=map(mapy(add distance))values
 fun origin x y values=toright x(down y values)
 fun place x y values=drawlines(origin x y values)
 val xymax=int 72
 fun lrinvert size values=map(mapx(fn x=>sub size x))values
 fun tbinvert size values=map(mapy(fn x=>sub size x))values
 fun rotatecw size values=map(fn value=>swapxy(mapy(fn x=>sub size x)value))values
 fun antirotate size values=map(fn value=>swapxy(mapx(fn x=>sub size x)value))values
 fun t4 values=F.defer(fn()=>
   let val(c1,c2,c3,c4)=list4 values
   in F.append c1(F.append(toright xymax c2)(F.append(down xymax c3)(down xymax(toright xymax c4))))end)
 fun col x y count values=F.defer(fn()=>if eq count(int 0)then text""
   else F.append(place x y values)(col x(add y(mul(int 2)xymax))(sub count(int 1))values))
 fun row x y count values=F.defer(fn()=>if eq count(int 0)then text""
   else F.append(place x y values)(row(add x(mul(int 2)xymax))y(sub count(int 1))values))
 fun tile x y columns rows values=F.defer(fn()=>
   if eq rows(int 0)then text""else if eq columns(int 0)then text""
   else F.append(col x y rows values)
      (F.append(row(add x(mul(int 2)xymax))y(sub columns(int 1))values)
      (tile(add x(mul(int 2)xymax))(add y(mul(int 2)xymax))(sub columns(int 1))(sub rows(int 1))values)))
 val dpxyorig=int 20 val dpxygap=int 20 val dpxynum=int 19
 val dpgrid=grid dpxyorig dpxyorig dpxygap dpxygap dpxynum dpxynum drawdot
 val designarea=ints[0,0,390,390]
 val tpxorig=int 524 val tpyorig=int 20 val tpxygap=int 72 val tpxynum=int 9
 val tpgrid=grid tpxorig tpyorig tpxygap tpxygap tpxynum tpxynum drawdot
 val tilearea=ints[521,18,580,580]
 val tmxorig=int 485 val tmyorig=int 282 val tmxygap=int 57 val tmxnum=int 1 val tmynum=int 6
 val tmgrid=grid tmxorig tmyorig tmxygap tmxygap tmxnum tmynum(circ(int 28))
 val dmxorig=int 425 val dmyorig=int 54 val dmxygap=int 57 val dmxnum=int 1 val dmynum=int 4
 val dmgrid=grid dmxorig dmyorig dmxygap dmxygap dmxnum dmynum(circ(int 28))
 val picxorig=int 624 val picyorig=int 676 val picxygap=int 100 val picxnum=int 4 val picynum=int 2
 val picgrid=grid(sub picxorig(int 1))(sub picyorig(int 1))picxygap picxygap picxnum picynum(squ(int 74))
 fun inrect x y width height xp yp=gt xp x andalso le xp(add x width)andalso gt yp y andalso le yp(add y height)
 fun inpicarea xp yp=inrect(int 624)(int 676)(int 400)(int 200)xp yp
 val picarea=ints[623,675,400,200]
 fun picbox(n:integer)=F.defer(fn()=>
   let fun rectangle x y=F.cons(x,F.cons(y,ints[72,72]))
   in case D.force n of
      0w1=>rectangle picxorig picyorig
     |0w2=>rectangle(add picxorig picxygap)picyorig
     |0w3=>rectangle(add picxorig(mul(int 2)picxygap))picyorig
     |0w4=>rectangle(add picxorig(mul(int 3)picxygap))picyorig
     |0w5=>rectangle picxorig(add picyorig picxygap)
     |0w6=>rectangle(add picxorig picxygap)(add picyorig picxygap)
     |0w7=>rectangle(add picxorig(mul(int 2)picxygap))(add picyorig picxygap)
     |0w8=>rectangle(add picxorig(mul(int 3)picxygap))(add picyorig picxygap)
     |_=>raise Match end)
 val textarea=ints[50,550,300,300]
 val vistextreg=textregion(ints[50,615,200,100])
 val helptextarea=ints[50,500,380,400]
 val invisibletext=F.append vistextreg(F.append(go(ints[500,500]))(F.append aligntext(text"\n")))
 fun cleara area=F.append(textregion area)(F.append clear invisibletext)
 fun pieces values=List.foldr(fn(value,rest)=>F.append value rest)(text"")values
 val menustrings=pieces[
   func(int 4),font(int 8),
   stringto(int 0)(int 405)(int 64)(text"DRAW"),
   stringto(int 0)(int 405)(int 121)(text"SAVE"),
   stringto(int 0)(int 410)(int 178)(text"GET"),
   stringto(int 0)(int 402)(int 235)(text"CLEAR"),
   stringto(int 0)(int 468)(int 292)(text"TILE"),
   stringto(int 0)(int 462)(int 349)(text"ALTER"),
   stringto(int 0)(int 468)(int 404)(text"SAVE"),
   stringto(int 0)(int 471)(int 463)(text"GET"),
   stringto(int 0)(int 464)(int 520)(text"CLEAR"),
   stringto(int 0)(int 474)(int 577)(text"T4"),font(int 12),
   stringto(int 0)(int 457)(int 729)(text"HELP"),
   stringto(int 0)(int 457)(int 829)(text"QUIT"),font(int 13),
   stringto(int 0)(int 112)(int 450)(text"STAMP DESIGN"),
   stringto(int 0)(int 730)(int 666)(text"TILE DESIGN"),func(int 15)]
 val dmcirc=circle(ints[425,54,30])
 val tmcirc=circle(ints[485,282,30])
 val amcirc=circle(ints[485,339,30])
 val hmcirc=circle(ints[485,712,38])
 fun modemark name=F.defer(fn()=>case string name of
      "draw"=>F.append dmcirc(undo(pieces[tmcirc,amcirc,hmcirc]))
     |"tile"=>F.append tmcirc(undo(pieces[dmcirc,amcirc,hmcirc]))
     |"alter"=>F.append amcirc(undo(pieces[dmcirc,tmcirc,hmcirc]))
     |"help"=>F.append hmcirc(undo(pieces[dmcirc,tmcirc,amcirc]))|_=>raise Match)
 fun menumark name=F.defer(fn()=>case string name of
      "tsave"=>circ(int 30)tmxorig(add tmyorig(mul(int 2)tmxygap))
     |"tget"=>circ(int 30)tmxorig(add tmyorig(mul(int 3)tmxygap))
     |"tclear"=>circ(int 30)tmxorig(add tmyorig(mul(int 4)tmxygap))
     |"t4"=>circ(int 30)tmxorig(add tmyorig(mul(int 5)tmxygap))
     |"dsave"=>circ(int 30)dmxorig(add dmyorig dmxygap)
     |"dget"=>circ(int 30)dmxorig(add dmyorig(mul(int 2)dmxygap))
     |"dclear"=>circ(int 30)dmxorig(add dmyorig(mul(int 3)dmxygap))|_=>raise Match)
 fun unmenumark value=undo(menumark value)
 fun incirc xc yc radius xp yp=le(add(square(sub xp xc))(square(sub yp yc)))(square radius)
 val tpwh=mul tpxygap(sub tpxynum(int 1))
 fun inbigtile x y=inrect tpxorig tpyorig tpwh tpwh x y
 fun indesign x y=inrect(int 0)(int 0)(int 390)(int 390)x y
 fun indgrid values=let val(x0,y0,x1,y1)=list4 values in indesign x0 y0 andalso indesign x1 y1 end
 fun intodraw x y=incirc dmxorig dmyorig(int 28)x y
 fun indsave x y=incirc dmxorig(add dmyorig dmxygap)(int 28)x y
 fun indget x y=incirc dmxorig(add dmyorig(mul(int 2)dmxygap))(int 28)x y
 fun indclear x y=incirc dmxorig(add dmyorig(mul(int 3)dmxygap))(int 28)x y
 fun intotile x y=incirc tmxorig tmyorig(int 28)x y
 fun intoalter x y=incirc tmxorig(add tmyorig tmxygap)(int 28)x y
 fun intsave x y=incirc tmxorig(add tmyorig(mul(int 2)tmxygap))(int 28)x y
 fun intget x y=incirc tmxorig(add tmyorig(mul(int 3)tmxygap))(int 28)x y
 fun intclear x y=incirc tmxorig(add tmyorig(mul(int 4)tmxygap))(int 28)x y
 fun intile4 x y=incirc tmxorig(add tmyorig(mul(int 5)tmxygap))(int 28)x y
 fun inhelp x y=incirc(int 485)(int 712)(int 36)x y
 fun inquit x y=incirc(int 485)(int 812)(int 36)x y
 val buttons=F.append(circle(ints[485,712,36]))(circle(ints[485,812,36]))
 val todesign=pieces[setevent(int 1)(text"msc %p\n"),setevent(int 2)(text"cs %l\n"),modemark(text"draw")]
 val totile=pieces[setevent(int 1)(text"msa %p\n"),setevent(int 2)(text"put %p\n"),tpgrid,modemark(text"tile")]
 val tofiddle=pieces[setevent(int 1)(text"msb %p\n"),setevent(int 2)(text"rot %p\n"),modemark(text"alter")]
 val tohelp=pieces[setevent(int 1)(text"msd %p\n"),setevent(int 2)(text"msd %p\n"),modemark(text"help")]
 val setup=pieces[textregion(ints[0,0,0,0]),clear,tpgrid,dpgrid,tmgrid,dmgrid,picgrid,buttons,invisibletext,menustrings,todesign]
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
 val helpsetup=F.append(textregion helptextarea)(font(int 8))
 val helpend=F.append(cleara helptextarea)(font(int 13))
 val endmes=pieces[text"\010\010 PRESS RETURN TO RETURN TO THE PROGRAM\010",text"OR CLICK SOMEWHERE ELSE TO FIND OUT MORE\010"]
 val helpdraw=pieces[text"This button puts you in drawing mode.\010",text"Lines can be drawn in the STAMP DESIGN \010",text"area by holding down the middle button,\010",text"and deleted by clicking\010",text"with the right one.\010",text"\010Little circles will appear if a line\010",text"touches the edge of the square.\010",text"These indicate positions on all the sides\010",text"that would contact that line in each of\010",text"the possible orientations of the print.\010",text"Unless special effects are being sought,\010",text"the recommendation is that all little\010",text"circles be attached to a line.\010",endmes]
 val helptile=pieces[text"In this mode, orientations of the print\010",text"can be placed in the TILE DESIGN area\010",text"to create a 64 X 64 big tile\010",text"\010Use the right button to select a print\010",text"and the middle button to place it.\010",text"\010Within the tiling area the right button\010",text"may also be used to delete a square\010",text"\010To rotate or invert squares within\010",text"the big tile it may be more convenient\010",text"to use the ALTER mode.",endmes]
 val helpalter=pieces[text"In ALTER mode, squares within the\010",text"big tile can be adjusted.\010",text"The middle button causes them to \010",text"rotate clockwise.\010",text"The right button causes them to\010",text"invert.",endmes]
 val helptsave=pieces[text"Sorry, SAVE is temporarily inoperative.",endmes]
 val helptclear=pieces[text"This CLEAR button clears the TILE DESIGN\010",text"region and draws an empty grid.",endmes]
 val helptget=pieces[text"Sorry, GET is temporarily inoperative.",endmes]
 val helpt4=pieces[text"The T4 button tiles the whole big tile\010",text"with the pattern of the four squares\010",text"in the top left hand corner\010",endmes]
 val helpquit=pieces[text"\010\010\010Clicking on QUIT allows you\010",text"to leave the program.\010",endmes]
 val helpbt=pieces[text"\010\010\010Within the TILE DESIGN area,\010",text"a big tile, based on orientations of\010",text"a print design, can be built.\010",text"\010Using TILE mode the right button\010",text"will select from a palette at the bottom\010",text"of the screen, and the middle button will\010",text"place the selection within the big tile.\010",text"Within the area the right button will\010",text"delete squares.\010",text"\010Using ALTER mode the right button will\010",text"invert squares, and the middle button \010",text"will rotate them.",endmes]
 val helppic=pieces[text"\010These boxes show the eight possible\010",text"orientations of the print that is\010",text"to be used in tiling\010",text"\010When in tiling mode, clicking with the\010",text"right button over one of these\010",text"will make it the \"current selection\".\010",text"Clicking with the middle button in\010",text"the TILE DESIGN grid, will put that\010",text"orientation of the print at that place",endmes]
 val helpdesign=pieces[text"\010\010\010This is the area in which to design \010your print.\010",text"\010Draw lines by holding down the\010 middle button.\010",text"Delete lines by clicking with the\010 right button.\010",text"\010\010A print that has previously been saved\010",text"can be restored by clicking on GET\010",text"then typing in the filename at the prompt.\010",endmes]
 val helpdsave=pieces[text"Sorry, SAVE is temporarily inoperative.",endmes]
 val helpdclear=pieces[text"\010\010\010This clears the PRINT DESIGN grid.\010",text"The print currently being worked on\010",text"will be lost, unless it has been\010",text"explicitly SAVEd first\010",endmes]
 val helpdget=pieces[text"Sorry, GET is temporarily inoperative.",endmes]
 val errmes=pieces[text"\010\010\010You have clicked over an area \010",text"of no particular interest.\010",endmes]
 val inithelp=pieces[helpsetup,clear,text"\010\010\010\010To find out the use of a particular\010",text"menu button or region of the screen, \010",text"click over the item you wish to\010",text"investigate.\010"]
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
 type inputLines=text C.seq
 type transition=(text*state*inputLines)L.delay
 fun matchPrefix prefix chars=
   let fun loop [] chars=SOME chars
         |loop(c::cs)chars=case D.force chars of F.Nil=>NONE
           |F.Cons(value,rest)=>if D.force value=c then loop cs rest else NONE
   in loop(String.explode prefix)chars end
 fun dropSpaces chars=F.defer(fn()=>case D.force chars of F.Nil=>F.empty()
   |F.Cons(value,rest)=>if Char.isSpace(D.force value)then dropSpaces rest else chars)
 fun words chars=F.defer(fn()=>
   let val chars=dropSpaces chars
       fun split chars=case D.force chars of F.Nil=>(F.empty(),chars)
         |F.Cons(c,rest)=>if Char.isSpace(D.force c)then(F.empty(),chars)
            else let val(word,tail)=split rest in(F.cons(c,word),tail)end
   in case D.force chars of F.Nil=>F.empty()
     |_=>let val(word,rest)=split chars in F.cons(word,words rest)end end)
 fun readInteger chars=D.delay(fn()=>
   let val value=string chars
       val normalized=if String.isPrefix"-"value then"~"^String.extract(value,1,NONE)else value
   in case IntInf.fromString normalized of NONE=>raise Fail"Prelude.read: no parse"
      |SOME n=>W.fromLargeInt n end)
 fun stoil chars=map readInteger(words chars)
 fun breakLine chars=L.delay(fn()=>case D.force chars of F.Nil=>(F.empty(),F.empty())
   |F.Cons(c,rest)=>if D.force c= #"\n"then(F.empty(),rest)
     else let val split=breakLine rest
          in(F.cons(c,F.defer(fn()=> #1(L.force split))),F.defer(fn()=> #2(L.force split)))end)
 fun lines chars=C.defer(fn()=>case D.force chars of F.Nil=>C.empty()
   |_=>let val split=breakLine chars
           val line=F.defer(fn()=> #1(L.force split))
           val rest=F.defer(fn()=> #2(L.force split))
       in C.cons(L.delay(fn()=>line),lines rest)end)
 fun input s=lines(text s)
 fun tileprompt _=text""
 fun tilequit _ values=case L.force values of C.Nil=>true
   |C.Cons(line,_)=>case D.force(L.force line)of F.Cons(c,_)=>D.force c= #"q"|F.Nil=>false
 fun inter(prompt:state->text)(endp:state->inputLines->bool)
   (transact:state->inputLines->transition)(state:state)(values:inputLines)=F.append(prompt state)(F.defer(fn()=>
   if endp state values then text""else
    let val step=L.delay(fn()=>L.force(transact state values))
        val response=F.defer(fn()=> #1(L.force step))
        val next=L.delay(fn()=>L.force(#2(L.force step)))
        val rest=L.delay(fn()=>L.force(#3(L.force step)))
    in F.append response(inter prompt endp transact next rest)end))
 fun tuple3 a b c=L.delay(fn()=>(a,b,c))
 fun stateFirst state=F.defer(fn()=>let val(a,_,_)=L.force state in a end)
 fun stateSecond state=D.delay(fn()=>let val(_,b,_)=L.force state in D.force b end)
 fun stateThird state=F.defer(fn()=>let val(_,_,c)=L.force state in c end)
 val initialState:state=L.delay(fn()=>(F.empty(),int 1,initalist))
 val newdraw=pieces[cleara designarea,dpgrid,cleara picarea,picgrid,cleara tilearea,tpgrid,invisibletext,todesign]
 fun getCoords drawing=map drawingLine drawing
 fun scaled drawing=map(map wscale)(getCoords drawing)
 fun todesignMode _ state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
   in(pieces[cleara picarea,picgrid,cleara tilearea,tpgrid,showoris(getCoords drawing)(int 1),todesign],
      L.delay(fn()=>(drawing,selection,tiles)),input)end)
 fun totileMode _ state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val coords=getCoords drawing
       val views=flatMap(showoris coords)(ints[1,2,3,4,5,6,7,8])
   in(F.append views totile,L.delay(fn()=>(drawing,selection,tiles)),input)end)
 fun tofiddleMode _ state input=L.delay(fn()=>let val(d,s,t)=L.force state in(tofiddle,L.delay(fn()=>(d,s,t)),input)end)
 fun tohelpMode _ state input=L.delay(fn()=>let val(d,s,t)=L.force state in(tohelp,L.delay(fn()=>(d,s,t)),input)end)
 fun rl rest state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val result=L.delay(fn()=>D.force(deline drawing(stoil rest)))
       val output=F.defer(fn()=> #1(L.force result))
       val next=L.delay(fn()=>(#2(L.force result),selection,tiles))
   in(output,next,input)end)
 fun dsave _ state input=tuple3(text"")state input
 fun dget _ state input=tuple3(text"")state input
 fun tsave _ state input=tuple3(text"")state input
 fun tget _ state input=tuple3(text"")state input
 fun dclear _ state input=L.delay(fn()=>
   let val(_,selection,_)=L.force state
   in(pieces[menumark(text"dclear"),newdraw,unmark selection,unmenumark(text"dclear")],initialState,input)end)
 fun selectMode rest state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val proposed=inbox(stoil rest)
       val next=D.delay(fn()=>D.force(if eq proposed(int 0)then selection else proposed))
   in(F.append(unmark selection)(mark next),L.delay(fn()=>(drawing,next,tiles)),input)end)
 fun delsq rest state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val point=stoil rest
       val old=assoc(sqid point)tiles
       val location=btlocate point
       val newtiles=newas(sqid point)(int 0)tiles
   in(undo(put location(orient xymax old(scaled drawing))),L.delay(fn()=>(drawing,selection,newtiles)),input)end)
 fun invMode rest state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val point=stoil rest val location=btlocate point
   in if eqIntegers location(ints[0,0])then(text"",L.delay(fn()=>(drawing,selection,tiles)),input)
      else let val old=assoc(sqid point)tiles
               val next=inv old
               val coords=scaled drawing
               val newtiles=newas(sqid point)next tiles
           in(F.append(undo(put location(orient xymax old coords)))(put location(orient xymax next coords)),
               L.delay(fn()=>(drawing,selection,newtiles)),input)end end)
 fun rotMode rest state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val point=stoil rest val location=btlocate point
   in if eqIntegers location(ints[0,0])then(text"",L.delay(fn()=>(drawing,selection,tiles)),input)
      else let val old=assoc(sqid point)tiles
               val next=rot old
               val coords=scaled drawing
               val newtiles=newas(sqid point)next tiles
           in(F.append(undo(put location(orient xymax old coords)))(put location(orient xymax next coords)),
               L.delay(fn()=>(drawing,selection,newtiles)),input)end end)
 fun putMode rest state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val point=stoil rest val location=btlocate point
   in if eqIntegers location(ints[0,0])then(text"",L.delay(fn()=>(drawing,selection,tiles)),input)
      else let val old=assoc(sqid point)tiles
               val coords=scaled drawing
               val newtiles=newas(sqid point)selection tiles
           in(F.append(undo(put location(orient xymax old coords)))(put location(orient xymax selection coords)),
               L.delay(fn()=>(drawing,selection,newtiles)),input)end end)
 fun tclear _ state input=L.delay(fn()=>
   let val(drawing,selection,_)=L.force state
   in(pieces[menumark(text"tclear"),cleara tilearea,tpgrid,totile,unmenumark(text"tclear")],
      L.delay(fn()=>(drawing,selection,initalist)),input)end)
 fun zip first second=F.defer(fn()=>case D.force first of F.Nil=>F.empty()
   |F.Cons(a,as')=>(case D.force second of F.Nil=>F.empty()
      |F.Cons(b,bs)=>F.cons(pair a b,zip as' bs)))
 fun t4Mode _ state input=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val keys=F.cons(pair(int 0)(int 0),F.cons(pair(int 0)(int 1),
          F.cons(pair(int 1)(int 0),singleton(pair(int 1)(int 1)))))
       val orientations=pam assoc keys tiles
       val coords=scaled drawing
       val picture=t4(pam(orient xymax)orientations coords)
       val newtiles=F.defer(fn()=>let val(n1,n2,n3,n4)=list4 orientations
             val first=concrep(int 4)(F.cons(n1,singleton n2))
             val second=concrep(int 4)(F.cons(n3,singleton n4))
           in zip alistind(concrep(int 4)(F.append first second))end)
   in(pieces[menumark(text"t4"),cleara tilearea,tile tpxorig tpyorig(int 4)(int 4)picture,unmenumark(text"t4")],
      L.delay(fn()=>(drawing,selection,newtiles)),input)end)
 fun q _ state _=tuple3(text"")state(C.empty())
 fun tiletrans state values=L.delay(fn()=>
   let val(drawing,selection,tiles)=L.force state
       val(first,input)=case L.force values of C.Nil=>raise Match|C.Cons(first,rest)=>(L.force first,rest)
       fun unchanged()=(text"",state,input)
       fun invoke handler rest=L.force(handler rest state input)
       fun msa rest=
         let val(x,y)=list2(stoil rest)
         in if intsave x y then invoke tsave rest
            else if intclear x y then invoke tclear rest
            else if intget x y then invoke tget rest
            else if intile4 x y then invoke t4Mode rest
            else if inquit x y then invoke q rest
            else if inbigtile x y then invoke delsq rest
            else if intoalter x y then invoke tofiddleMode rest
            else if intotile x y then invoke totileMode rest
            else if intodraw x y then invoke todesignMode rest
            else if inpicarea x y then invoke selectMode rest
            else if inhelp x y then invoke tohelpMode rest
            else L.force(tiletrans state input)end
       fun msb rest=
         let val(x,y)=list2(stoil rest)
         in if inbigtile x y then invoke invMode rest
            else L.force(tiletrans state(C.cons(L.delay(fn()=>F.append(text"msa ")rest),input)))end
       fun msc rest=
         let val(x,y)=list2(stoil rest)
         in if indesign x y then invoke rl rest
            else if indsave x y then invoke dsave rest
            else if indclear x y then invoke dclear rest
            else if indget x y then invoke dget rest
            else L.force(tiletrans state(C.cons(L.delay(fn()=>F.append(text"msa ")rest),input)))end
       fun msd rest=
         let val(x,y)=list2(stoil rest)
             fun cf value=F.append clear value
             val out=F.defer(fn()=>
               if intodraw x y then cf helpdraw
               else if intotile x y then cf helptile
               else if intoalter x y then cf helpalter
               else if intsave x y then cf helptsave
               else if intclear x y then cf helptclear
               else if intget x y then cf helptget
               else if intile4 x y then cf helpt4
               else if inquit x y then cf helpquit
               else if inbigtile x y then cf helpbt
               else if inpicarea x y then cf helppic
               else if indesign x y then cf helpdesign
               else if indsave x y then cf helpdsave
               else if indclear x y then cf helpdclear
               else if indget x y then cf helpdget
               else if inhelp x y then cf inithelp else cf errmes)
         in(F.append inithelp out,state,input)end
       fun draw rest=
         let val(x0,y0,x1,y1)=list4(stoil rest)
             val nearline=F.cons(nearx x0,F.cons(neary y0,F.cons(nearx x1,singleton(neary y1))))
         in if indgrid nearline then
             let val cssr=L.delay(fn()=>D.force(cs nearline))
                 val output=F.defer(fn()=> #1(L.force cssr))
                 val circles=F.defer(fn()=> #2(L.force cssr))
                 val entry=pair nearline circles
             in(F.append output(wline nearline),L.delay(fn()=>(F.cons(entry,drawing),selection,tiles)),input)end
            else unchanged()end
   in case matchPrefix"msa "first of SOME rest=>msa rest|NONE=>
      case matchPrefix"msb "first of SOME rest=>msb rest|NONE=>
      case matchPrefix"msc "first of SOME rest=>msc rest|NONE=>
      case matchPrefix"msd "first of SOME rest=>msd rest|NONE=>
      case matchPrefix"cs "first of SOME rest=>draw rest|NONE=>
      case matchPrefix"rot "first of SOME rest=>invoke rotMode rest|NONE=>
      case matchPrefix"put "first of SOME rest=>invoke putMode rest|NONE=>
      if null first then(F.append helpend todesign,state,input)else unchanged()
   end)
 fun potatotile state input=inter tileprompt tilequit tiletrans state input
 fun program input=pieces[setmode(int 7),shapewindow(ints[0,0,1150,900]),setup,
   potatotile initialState input,shapewindow(ints[0,0,500,500]),font(int 8),textreset,clear,func(int 15)]
 fun hash chars=
   let fun loop value chars=case D.force chars of F.Nil=>value
         |F.Cons(c,rest)=>loop(W.+(W.fromInt(Char.ord(D.force c)),W.*(value,0w31)))rest
   in loop 0w0 chars end
 fun signedHash word=
   let val n=W.toLargeInt word
       val signed=if S.negative word then n-18446744073709551616 else n
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString signed)end
 type input=inputLines
 fun benchmark input=hash(program input)

end
