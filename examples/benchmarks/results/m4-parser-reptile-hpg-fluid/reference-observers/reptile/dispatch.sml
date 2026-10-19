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
