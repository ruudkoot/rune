 fun thenCompare EQUAL next=next()|thenCompare answer _=answer
 fun domainTag Two=0|domainTag(Lift1 _)=1|domainTag(Lift2 _)=2|domainTag(Func _)=3
 fun compareDomain a b=
   let val x=force a val y=force b
   in case(x,y)of
      (Two,Two)=>EQUAL
     |(Lift1 xs,Lift1 ys)=>compareLists compareDomain xs ys
     |(Lift2 xs,Lift2 ys)=>compareLists compareDomain xs ys
     |(Func(xs,x),Func(ys,y))=>thenCompare(compareLists compareDomain xs ys)(fn()=>compareDomain x y)
     |_=>Int.compare(domainTag x,domainTag y)end
 fun equalDomain a b=compareDomain a b=EQUAL
 fun routeTag Zero=0|routeTag One=1|routeTag Stop1=2|routeTag(Up1 _)=3
   |routeTag Stop2=4|routeTag Up2=5|routeTag(UpUp2 _)=6|routeTag(Rep _)=7
 fun repTag(RepTwo _)=0|repTag(Rep1 _)=1|repTag(Rep2 _)=2
 fun compareRoute a b=
   let val x=force a val y=force b
   in case(x,y)of(Zero,Zero)=>EQUAL|(One,One)=>EQUAL|(Stop1,Stop1)=>EQUAL
     |(Stop2,Stop2)=>EQUAL|(Up2,Up2)=>EQUAL
     |(Up1 xs,Up1 ys)=>compareLists compareRoute xs ys
     |(UpUp2 xs,UpUp2 ys)=>compareLists compareRoute xs ys
     |(Rep x,Rep y)=>compareRep x y
     |_=>Int.compare(routeTag x,routeTag y)end
 and compareRep a b=
   let val x=force a val y=force b
   in case(x,y)of
      (RepTwo x,RepTwo y)=>compareFrontier x y
     |(Rep1(x,xs),Rep1(y,ys))=>thenCompare(compareFrontier x y)(fn()=>compareLists compareRep xs ys)
     |(Rep2(x,z,xs),Rep2(y,w,ys))=>thenCompare(compareFrontier x y)(fn()=>
          thenCompare(compareFrontier z w)(fn()=>compareLists compareRep xs ys))
     |_=>Int.compare(repTag x,repTag y)end
 and compareFrontier a b=
   let val Min1Max0(n,xs,ys)=force a val Min1Max0(m,zs,ws)=force b
   in thenCompare(compareInt n m)(fn()=>thenCompare(compareLists compareFrel xs zs)
       (fn()=>compareLists compareFrel ys ws))end
 and compareFrel a b=let val MkFrel xs=force a val MkFrel ys=force b
   in compareLists compareRoute xs ys end
 fun equalRoute a b=compareRoute a b=EQUAL
 fun equalRep a b=compareRep a b=EQUAL
 fun equalFrontier a b=compareFrontier a b=EQUAL
 fun equalFrel a b=compareFrel a b=EQUAL
 fun equalType a b=case(force a,force b)of
    (TVar x,TVar y)=>let val(a,b)=force x val(c,d)=force y
      in equalLists equalInt a c andalso equalLists equalInt b d end
   |(TArr(a,b),TArr(c,d))=>equalType a c andalso equalType b d
   |(TCons(name,xs),TCons(other,ys))=>equalName name other andalso equalLists equalType xs ys
   |_=>false
 fun equalDexpr a b=case(force a,force b)of
    (DXTwo,DXTwo)=>true|(DXLift1 xs,DXLift1 ys)=>equalLists equalDexpr xs ys
   |(DXLift2 xs,DXLift2 ys)=>equalLists equalDexpr xs ys
   |(DXFunc(xs,x),DXFunc(ys,y))=>equalLists equalDexpr xs ys andalso equalDexpr x y
   |(DXVar x,DXVar y)=>equalName x y|_=>false
 fun compareConstructor a b=case(force a,force b)of
    (ConstrRec,ConstrRec)=>EQUAL|(ConstrRec,_)=>LESS|(_,ConstrRec)=>GREATER
   |(ConstrVar x,ConstrVar y)=>compareInt x y
 fun equalFlag a b=
   let fun tag Typecheck=0|tag Simp=1|tag NoCaseOpt=2|tag ShowHExpr=3
        |tag NoPretty=4|tag NoFormat=5|tag NoBaraki=6|tag SimpleInv=7
        |tag(PolyLim _)=8|tag(MonoLim _)=9|tag ForceAll=10|tag DryRun=11
        |tag(LowerLim _)=12|tag(UpperLim _)=13|tag(ScaleUp _)=14
       val x=force a val y=force b
   in case(x,y)of(PolyLim x,PolyLim y)=>equalInt x y
      |(MonoLim x,MonoLim y)=>equalInt x y|(LowerLim x,LowerLim y)=>equalInt x y
      |(UpperLim x,UpperLim y)=>equalInt x y|(ScaleUp x,ScaleUp y)=>equalInt x y
      |_=>tag x=tag y end
