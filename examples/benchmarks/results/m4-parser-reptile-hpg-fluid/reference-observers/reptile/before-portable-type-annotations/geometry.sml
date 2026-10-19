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
