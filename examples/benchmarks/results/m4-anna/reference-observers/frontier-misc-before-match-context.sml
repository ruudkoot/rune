 fun splitBy predicate values=L.delay(fn()=>case force values of F.Nil=>(F.empty(),F.empty())
   |F.Cons(x,rest)=>let val(yes,no)=L.force(splitBy predicate rest)
     in if predicate x then(F.cons(x,yes),no)else(yes,F.cons(x,no))end)
 fun combineBounds upper lower:representation=D.delay(fn()=>case(force upper,force lower)of
    (RepTwo x,RepTwo y)=>RepTwo(combineFrontierBounds x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(combineFrontierBounds x y,zipExact combineBounds xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(combineFrontierBounds x y,combineFrontierBounds z w,zipExact combineBounds xs ys)
   |_=>raise Match)
 and combineFrontierBounds upper lower:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force upper val Min1Max0(_,ones,_)=force lower
   in Min1Max0(arity,ones,zeros)end)
 fun selectFrontier random upSpace downSpace fromTop=
   let
     fun inner mi values rest=C.defer(fn()=>case force values of F.Nil=>rest()
       |F.Cons(ma,tail)=>if belowFrel mi ma then
          C.cons(L.delay(fn()=>pair mi ma),inner mi tail rest)else inner mi tail rest)
     fun outer values=C.defer(fn()=>case force values of F.Nil=>C.empty()
       |F.Cons(mi,tail)=>inner mi downSpace(fn()=>outer tail))
     val pairs=fromControl(C.take 30(outer upSpace))
   in if null pairs then NONE else
     let val index=modulo random(length pairs)val(mi,ma)=force(nth pairs index)
     in SOME(if fromTop then ma else mi)end end
 fun frontierMaximumIntersection xs ys=maximal belowFrel(flatMap(fn x=>map(meetFrel x)ys)xs)
 fun frontierMinimumIntersection xs ys=minimal belowFrel(flatMap(fn x=>map(joinFrel x)ys)xs)
 fun reviseMinimum domains minimum point=
   let val partition=splitBy(fn x=>belowFrel x point)minimum
       val(underneath,others)=L.force partition
       val changed=frontierMinimumIntersection underneath(successorFrels domains point)
   in if less(length changed)(length others)then foldRight(minimumAdd belowFrel)changed others
      else foldRight(minimumAdd belowFrel)others changed end
 fun reviseMaximum domains maximum point=
   let val(above,others)=L.force(splitBy(fn y=>belowFrel point y)maximum)
       val changed=frontierMaximumIntersection above(predecessorFrels domains point)
   in if less(length changed)(length others)then foldRight(maximumAdd belowFrel)others changed
      else foldRight(maximumAdd belowFrel)changed others end
 val randomModulus1=cell(0w2147483563:W.word)
 val randomModulus2=cell(0w2147483399:W.word)
 val randomLimit1=cell(0w2147483562:W.word)
 val randomLimit2=cell(0w2147483398:W.word)
 fun randomIntegers seed1 seed2=
   let fun rands a b=C.defer(fn()=>
         let val k=divide a(int 53668)
             val nextA=subtract(multiply(int 40014)(subtract a(multiply k(int 53668))))(multiply k(int 12211))
             val a=D.delay(fn()=>force(if less nextA(int 0)then add nextA randomModulus1 else nextA))
             val k=divide b(int 52774)
             val nextB=subtract(multiply(int 40692)(subtract b(multiply k(int 52774))))(multiply k(int 3791))
             val b=D.delay(fn()=>force(if less nextB(int 0)then add nextB randomModulus2 else nextB))
             val z=subtract a b
             val result=if less z(int 1)then add z randomLimit1 else z
         in C.cons(L.delay(fn()=>result),C.defer(fn()=>rands a b))end)
   in if leq(int 1)seed1 andalso leq seed1 randomLimit1 andalso leq(int 1)seed2 andalso leq seed2 randomLimit2
       then rands seed1 seed2 else panic"utRandomInts: bad seeds"end
