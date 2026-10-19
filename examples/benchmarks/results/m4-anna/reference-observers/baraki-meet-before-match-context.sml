
 fun barakiBelow left right=case force left of
    Zero=>true|One=>(case force right of One=>true|Zero=>false|_=>raise Match)
   |Stop1=>true|Up1 xs=>(case force right of Up1 ys=>andWith barakiBelow xs ys|_=>false)
   |Stop2=>true|Up2=>(case force right of Stop2=>false|_=>true)
   |UpUp2 xs=>(case force right of UpUp2 ys=>andWith barakiBelow xs ys|_=>false)
   |Rep x=>(case force right of Rep y=>barakiBelowRepresentation x y|_=>raise Match)
 and barakiBelowRepresentation left right=case(force left,force right)of
    (RepTwo x,RepTwo y)=>barakiBelowFrontier x y
   |(Rep1(x,xs),Rep1(y,ys))=>barakiBelowFrontier x y andalso andWith barakiBelowRepresentation xs ys
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>barakiBelowFrontier x y andalso barakiBelowFrontier z w
        andalso andWith barakiBelowRepresentation xs ys
   |_=>raise Match
 and barakiBelowFrontier left right=
   let val Min1Max0(_,_,xs)=force left val Min1Max0(_,_,ys)=force right
   in all(fn y=>any(fn x=>barakiBelowFrel y x)xs)ys end
 and barakiBelowFrel left right=
   let val MkFrel xs=force left val MkFrel ys=force right in andWith barakiBelow xs ys end
 fun barakiMaximumAdd x others=F.defer(fn()=>if any(barakiBelowFrel x)others then others
    else F.cons(x,filter(fn y=>not(barakiBelowFrel y x))others))
 fun barakiMeetFrontier left right:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force left val Min1Max0(_,_,others)=force right
   in Min1Max0(arity,F.empty(),foldRight barakiMaximumAdd zeros others)end)
 fun barakiMeetRepresentation left right:representation=D.delay(fn()=>case(force left,force right)of
    (RepTwo x,RepTwo y)=>RepTwo(barakiMeetFrontier x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(barakiMeetFrontier x y,zipExact barakiMeetRepresentation xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(barakiMeetFrontier x y,barakiMeetFrontier z w,zipExact barakiMeetRepresentation xs ys)
   |_=>raise Match)
 fun barakiMeet left right:route=D.delay(fn()=>case(force left,force right)of
    (Rep x,Rep y)=>Rep(barakiMeetRepresentation x y)|_=>raise Match)
 fun normalizeBaraki domain point:route=D.delay(fn()=>case(force domain,force point)of
    (Two,_)=>force point|(Lift1 _,Stop1)=>force point
   |(Lift1 ds,Up1 rs)=>Up1(zipExact normalizeBaraki ds rs)
   |(Lift2 _,Stop2)=>force point|(Lift2 _,Up2)=>force point
   |(Lift2 ds,UpUp2 rs)=>UpUp2(zipExact normalizeBaraki ds rs)
   |(_,Rep rep)=>Rep(normalizeBarakiRepresentation domain rep)|_=>raise Match)
 and normalizeBarakiRepresentation domain rep:representation=D.delay(fn()=>case(force domain,force rep)of
    (Func(args,result),RepTwo f)=>(case force result of Two=>RepTwo(normalizeBarakiFrontier args f)|_=>raise Match)
   |(Func(args,result),Rep1(f,highs))=>(case force result of Lift1 targets=>
        Rep1(normalizeBarakiFrontier args f,zipExact normalizeBarakiRepresentation(map(uncurryDomain args)targets)highs)|_=>raise Match)
   |(Func(args,result),Rep2(f,m,highs))=>(case force result of Lift2 targets=>
        Rep2(normalizeBarakiFrontier args f,normalizeBarakiFrontier args m,
          zipExact normalizeBarakiRepresentation(map(uncurryDomain args)targets)highs)|_=>raise Match)
   |_=>raise Match)
 and normalizeBarakiFrontier arguments frontier:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force frontier
       fun norm value=let val MkFrel routes=force value in cell(MkFrel(zipExact normalizeBaraki arguments routes))end
       val normalized=insertionSort compareFrel(map norm zeros)
       (* The original deliberately computes min1 from the OLD max0. *)
       val ones=minOneFromMaxZero arguments zeros
   in Min1Max0(arity,ones,normalized)end)
