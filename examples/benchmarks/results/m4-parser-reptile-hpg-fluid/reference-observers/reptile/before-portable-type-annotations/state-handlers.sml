 val initialState=L.delay(fn()=>(F.empty(),int 1,initalist))
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
