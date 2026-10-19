 fun belowRoute left right=case force left of
    Zero=>true|Stop1=>true|Stop2=>true
   |One=>(case force right of One=>true|Zero=>false|_=>raise Match)
   |Up1 xs=>(case force right of Up1 ys=>belowRouteList xs ys|_=>false)
   |Up2=>(case force right of Stop2=>false|_=>true)
   |UpUp2 xs=>(case force right of UpUp2 ys=>belowRouteList xs ys|_=>false)
   |Rep r=>(case force right of Rep s=>belowRepresentation r s|_=>raise Match)
 and belowRouteList xs ys=
   let fun mismatch()=panic"avLEQR_list: unequal lists"
   in case(force xs,force ys)of(F.Nil,F.Nil)=>true
     |(F.Cons(a,at),F.Cons(b,bt))=>(case(force at,force bt)of
        (F.Nil,F.Nil)=>belowRoute a b
       |(F.Cons(c,ct),F.Cons(d,dt))=>(case(force ct,force dt)of
          (F.Nil,F.Nil)=>belowRoute a b andalso belowRoute c d
         |(F.Cons(e,et),F.Cons(f,ft))=>(case(force et,force ft)of
            (F.Nil,F.Nil)=>belowRoute a b andalso belowRoute c d andalso belowRoute e f
           |(F.Cons(g,gt),F.Cons(h,ht))=>(case(force gt,force ht)of
              (F.Nil,F.Nil)=>belowRoute a b andalso belowRoute c d andalso belowRoute e f andalso belowRoute g h
             |(F.Cons _,F.Cons _)=>belowRoute a b andalso belowRoute c d andalso belowRoute e f
                    andalso belowRoute g h andalso belowRouteList gt ht
             |_=>mismatch())
           |_=>mismatch())
         |_=>mismatch())
       |_=>mismatch())
     |_=>mismatch()end
 and belowFrel left right=let val MkFrel xs=force left val MkFrel ys=force right
   in belowRouteList xs ys end
 and belowFrontier left right=
   let val Min1Max0(_,ones,_)=force left val Min1Max0(_,targets,_)=force right
       fun inner y values=case force values of F.Nil=>false|F.Cons(z,rest)=>
          if belowFrel z y then true else inner y rest
       fun outer values=case force values of F.Nil=>true|F.Cons(x,rest)=>
          if inner x targets then outer rest else false
   in outer ones end
 and belowRepresentation left right=
   let fun exact xs ys=case(force xs,force ys)of(F.Nil,F.Nil)=>true
          |(F.Cons(x,xt),F.Cons(y,yt))=>belowRepresentation x y andalso exact xt yt
          |_=>panic"myAndWith2: unequal lists"
   in case(force left,force right)of
       (RepTwo x,RepTwo y)=>belowFrontier x y
      |(Rep1(x,xs),Rep1(y,ys))=>belowFrontier x y andalso exact xs ys
      |(Rep2(x,z,xs),Rep2(y,w,ys))=>belowFrontier x y andalso belowFrontier z w andalso exact xs ys
      |_=>raise Match end
 fun minimumAdd below x ys=F.defer(fn()=>if any(fn y=>below y x)ys then ys
   else F.cons(x,filter(fn y=>not(below x y))ys))
 fun maximumAdd below x ys=F.defer(fn()=>if any(fn y=>below x y)ys then ys
   else F.cons(x,filter(fn y=>not(below y x))ys))
 fun minimal below values=foldRight(minimumAdd below)(F.empty())values
 fun maximal below values=foldRight(maximumAdd below)(F.empty())values
