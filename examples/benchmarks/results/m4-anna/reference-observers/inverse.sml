 fun normalizeInverse maxima minima=
   let val maxima=filter(fn x=>any(fn y=>belowFrel y x)minima)maxima
       val minima=filter(fn x=>any(fn y=>belowFrel x y)maxima)minima
   in(maxima,minima)end
 fun intersectInverse(max1,min1)(max2,min2)=
   let val maxima=maximal belowFrel(flatMap(fn x=>map(meetFrel x)max2)max1)
       val minima=minimal belowFrel(flatMap(fn x=>map(joinFrel x)min2)min1)
   in normalizeInverse maxima minima end
 fun inverseEnumerated arguments function result=
   let val actualArguments=F.defer(fn()=>case force result of Rep resultRep=>
          take(subtract(representationArity function)(representationArity resultRep))arguments|_=>arguments)
       val combinations=cartesianProduct(map allRoutes actualArguments)
   in map(fn args=>cell(MkFrel args))
       (filter(fn args=>equalRoute(applyRoute(cell(Rep function))args)result)combinations)end
 fun inverseMindless domain function result=L.delay(fn()=>case force domain of Func(arguments,_)=>
   let val image=inverseEnumerated arguments function result
   in(maximal belowFrel image,minimal belowFrel image)end|_=>raise Match)
 fun inverseMMI domain function result=L.delay(fn()=>case(force domain,force function,force result)of
    (Func(arguments,_),RepTwo f,Zero)=>let val Min1Max0(_,_,zeros)=force f
       val minima=F.defer(fn()=>if null zeros then F.empty()else singleton(cell(MkFrel(map bottomRoute arguments))))
     in(zeros,minima)end
   |(Func(arguments,target),RepTwo f,One)=>(case force target of Two=>
      let val Min1Max0(_,ones,_)=force f
          val maxima=F.defer(fn()=>if null ones then F.empty()else singleton(cell(MkFrel(map topRoute arguments))))
      in(maxima,ones)end|_=>L.force(inverseMindless domain function result))
   |(Func(arguments,target),Rep1(low,highs),point)=>(case(force target,point)of
      (Lift1 _,Stop1)=>let val Min1Max0(_,_,zeros)=force low
         val minima=F.defer(fn()=>if null zeros then F.empty()else singleton(cell(MkFrel(map bottomRoute arguments))))
        in(zeros,minima)end
     |(Lift1 targets,Up1 routes)=>
        let val Min1Max0(_,ones,_)=force low
            val inverse=if isSingletonList targets andalso isSingletonList highs andalso isSingletonList routes
              then inverseMMI(uncurryDomain arguments(head targets))(head highs)(head routes)
              else L.delay(fn()=>let val domains=map(uncurryDomain arguments)targets
                  val results=zip3Exact(fn d=>fn f=>fn r=>D.delay(fn()=>L.force(inverseMMI d f r)))domains highs routes
                  val combined=foldRight1(fn a=>fn b=>D.delay(fn()=>intersectInverse(force a)(force b)))results
                in force combined end)
            val maxima=F.defer(fn()=> #1(L.force inverse))
            val minima=F.defer(fn()=> #2(L.force inverse))
            val minima=minimal belowFrel(flatMap(fn x=>map(joinFrel x)ones)minima)
        in normalizeInverse maxima minima end
     |_=>L.force(inverseMindless domain function result))
   |(Func(arguments,target),Rep2(low,middle,highs),_) =>(case force target of Lift2 targets=>
       let val isoDomain=cell(Func(arguments,cell(Lift1(singleton(cell(Lift1 targets))))))
           val isoRoute=cell(Rep1(low,singleton(cell(Rep1(middle,highs)))))
           val isoResult=D.delay(fn()=>case force result of Stop2=>Stop1
              |Up2=>Up1(singleton(cell Stop1))|UpUp2 rs=>Up1(singleton(cell(Up1 rs)))|_=>raise Match)
       in L.force(inverseMMI isoDomain isoRoute isoResult)end
       |_=>L.force(inverseMindless domain function result))
   |_=>L.force(inverseMindless domain function result))
 fun minimumInverse mindless domain point result=F.defer(fn()=>case force point of Rep rep=>
     let val answer=if mindless then inverseMindless domain rep result else inverseMMI domain rep result
     in #2(L.force answer)end|_=>raise Match)
 fun maximumInverse mindless domain point result=F.defer(fn()=>case force point of Rep rep=>
     let val answer=if mindless then inverseMindless domain rep result else inverseMMI domain rep result
     in #1(L.force answer)end|_=>raise Match)
