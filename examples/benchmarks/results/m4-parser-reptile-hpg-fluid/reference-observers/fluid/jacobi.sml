 fun sparseElements array=map(fn p=> #2(force p))(A.sparseAssociations array)
 fun jacobi step(elementFactors:elementFactor A.array)table velocitySteer(allBoundary,(xFixed,yFixed))(b1,b2)
       scalar maxIter iterTolerance relax=
   let val bnds=A.bounds table
       val initial=A.array bnds(F.empty())
       val diagonal=A.listArray bnds
         (map(fn i=>sum(map(fn entry=>let val(e,id)=force entry
           in mul(#1(force(A.lookup elementFactors e)))(A.lookup massRowSums id)end)
           (force(A.lookup table(force i)))))(range(#1 bnds)(#2 bnds)))
       fun iterate(old1,old2)n=
         let
           fun findDiff fixed x b=
             A.defListArray eq bnds zero
               (map(fn i=>D.delay(fn()=>if force(A.lookup fixed(force i))then 0.0 else
                 let val scaled=divide(A.lookup b(force i))scalar
                     val residual=D.delay(fn()=>if n=maxIter then force scaled else
                       force(sub scaled(sum(map(fn entry=>
                         let val(e,id)=force entry
                             val area= #1(force(A.lookup elementFactors e))
                             val row=map(mult area)(force(A.lookup massMatrix id))
                         in listInnerProd(getValues x(force(A.lookup velocitySteer e)))row end)
                          (force(A.lookup table(force i)))))))
                 in force(divide(mul residual relax)(A.lookup diagonal(force i)))end))
                (range(#1 bnds)(#2 bnds)))
           val diff=if step=1 then(findDiff xFixed old1 b1,findDiff yFixed old2 b2)
             else(findDiff allBoundary old1 b1,findDiff allBoundary old2 b2)
           val next=if n=maxIter then diff else addU(old1,old2)diff
           val finished=n<=1 orelse(n<>maxIter andalso
             lt(tolerance(F.append(A.elements(#1 next))(A.elements(#2 next)))
                  (F.append(sparseElements(#1 diff))(sparseElements(#2 diff)))true)iterTolerance)
         in if finished then next else iterate next(n-1)end
   in iterate(initial,initial)maxIter end
