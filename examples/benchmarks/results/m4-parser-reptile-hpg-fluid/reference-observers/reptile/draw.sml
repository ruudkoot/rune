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
