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
