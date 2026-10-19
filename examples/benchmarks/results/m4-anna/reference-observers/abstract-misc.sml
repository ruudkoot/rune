 fun immediateAbove domain point=map(joinRoute point)(successors domain point)
 fun immediateBelow domain point=map(meetRoute point)(predecessors domain point)
 fun pushUp domain points=F.defer(fn()=>if null points then F.empty()
   else unique equalRoute(concat(map(immediateAbove domain)points)))
 fun pushDown domain points=F.defer(fn()=>if null points then F.empty()
   else unique equalRoute(concat(map(immediateBelow domain)points)))
 fun slices step initial=
   let fun produce slice=C.defer(fn()=>C.cons(L.delay(fn()=>slice),produce(step slice)))
       fun consume values=F.defer(fn()=>case L.force values of C.Nil=>F.empty()
         |C.Cons(slice,rest)=>let val slice=L.force slice
           in if null slice then F.empty()else F.cons(slice,consume rest)end)
   in consume(produce initial)end
 fun allUpSlices domain=slices(pushUp domain)(singleton(bottomRoute domain))
 fun allDownSlices domain=slices(pushDown domain)(singleton(topRoute domain))
 fun allRoutes domain=F.defer(fn()=>case force domain of Two=>F.fromList[Zero,One]
   |Lift1 ds=>F.cons(cell Stop1,map(fn routes=>cell(Up1 routes))(cartesianProduct(map allRoutes ds)))
   |Lift2 ds=>F.cons(cell Stop2,F.cons(cell Up2,
        map(fn routes=>cell(UpUp2 routes))(cartesianProduct(map allRoutes ds))))
   |Func(arguments,result)=>concat(allUpSlices(cell(Func(arguments,result)))))
 fun upwardClosure domain points=F.defer(fn()=>case force points of F.Nil=>F.empty()
   |F.Cons(x,_)=>F.cons(x,upwardClosure domain(minimal belowRoute(
       flatMap(fn y=>map(joinRoute y)(successors domain x))points))))
 fun downwardClosure domain points=F.defer(fn()=>case force points of F.Nil=>F.empty()
   |F.Cons(x,_)=>F.cons(x,downwardClosure domain(maximal belowRoute(
       flatMap(fn y=>map(meetRoute y)(predecessors domain x))points))))
 fun allRoutesMinusTop domain=downwardClosure domain(predecessors domain(topRoute domain))
 fun equalPoints(a,x)(b,y)=if equalDomain a b then equalRoute x y else panic"Comparing points in different domains."
 fun containsFunctions domain=case force domain of Two=>false
   |Lift1 ds=>any containsFunctions ds|Lift2 ds=>any containsFunctions ds|Func _=>true
 fun isHigherOrderFunction domain=case force domain of Func(args,result)=>
    containsFunctions result orelse any containsFunctions args|_=>raise Match
 fun isDataFunction domain=case force domain of Func(_,result)=>not(containsFunctions result)|_=>raise Match
 fun representationArity rep=let val low=case force rep of RepTwo low=>low|Rep1(low,_)=>low|Rep2(low,_,_)=>low
      val Min1Max0(arity,_,_)=force low
   in arity end
 fun strongNormalize domain:domain=D.delay(fn()=>case force domain of Two=>Two
   |Lift1 ds=>Lift1(map strongNormalize ds)|Lift2 ds=>Lift2(map strongNormalize ds)
   |Func(arguments,result)=>(case force result of Func(more,result)=>
       force(strongNormalize(cell(Func(F.append arguments more,result))))
      |_=>Func(map strongNormalize arguments,strongNormalize result)))
 fun meetIrreducibleRoutes domain=F.defer(fn()=>case force domain of Two=>singleton(cell Zero)
   |Lift1 ds=>F.cons(cell Stop1,map(fn routes=>cell(Up1 routes))
       (listVariants(map topRoute ds)(map meetIrreducibleRoutes ds)))
   |Lift2 ds=>F.cons(cell Stop2,F.cons(cell Up2,map(fn routes=>cell(UpUp2 routes))
       (listVariants(map topRoute ds)(map meetIrreducibleRoutes ds))))
   |_=>raise Match)
