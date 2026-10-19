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
