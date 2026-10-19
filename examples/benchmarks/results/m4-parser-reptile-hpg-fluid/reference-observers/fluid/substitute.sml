 fun lowerPart upper off=dropWhile(fn p=> #1(force p)<=upper)(A.sparseAssociations off)
 fun forwardSubstitution(factors:block A.array)b=
   let val upper= #2(A.bounds factors)
       fun loop block b result=if block>upper then result else
         let val(diag,off)=force(A.lookup factors block)
             val(lo,hi)=A.bounds diag
             fun solve i result=if i>hi then result else
               let val(start,values)=force(A.lookup off i)
                   val next=divide(sub(A.lookup b i)
                     (listInnerProd(F.drop(start-lo)result)values))(A.lookup diag i)
               in solve(i+1)(F.append result(singleton next))end
             val next=solve(lo+1)(singleton(divide(A.lookup b lo)(A.lookup diag lo)))
             val revised=A.accum eq sub b(map(fn entry=>
               let val(index,segment)=force entry val(start,values)=force segment
               in pair index(listInnerProd(F.drop(start-lo)next)values)end)(lowerPart hi off))
         in loop(block+1)revised(F.append result next)end
   in A.listArray(A.bounds b)(loop 1 b(F.empty()))end
 fun backwardSubstitution(factors:block A.array)y=
   let val upper= #2(A.bounds factors)
       fun loop block result=if block<1 then result else
         let val(diag,off)=force(A.lookup factors block)
             val bnds as(lo,hi)=A.bounds diag
             val changes=A.flatMap(fn entry=>let val(index,segment)=force entry
                 val(start,values)=force segment
               in zipWith(fn i=>fn v=>pair(force i)v)(range start hi)
                    (map(fn v=>mul(A.lookup result index)v)values)end)(lowerPart hi off)
             val b=A.accum eq sub(A.listArray bnds(map(fn i=>A.lookup y(force i))(range lo hi)))changes
             fun solve i bRoot result=if i<lo then result else
               let val b=L.force bRoot
                   val next=divide(A.lookup b i)(A.lookup diag i)
                   val revised=L.delay(fn()=>let val(start,values)=force(A.lookup off i)
                     val changes=zipWith(fn i=>fn v=>pair(force i)v)(range start(i-1))(map(mul next)values)
                     in A.accum eq sub b changes end)
               in solve(i-1)revised(A.update eq result(singleton(pair i next)))end
         in loop(block-1)(solve hi(L.delay(fn()=>b))result)end
   in loop upper(A.array(A.bounds y)(F.empty()))end
 fun choleskyMethod(factors:block A.array,mapping:int A.array)(b:realArray)scalar=
   let val bnds=A.bounds b
       val revised=A.array bnds(map(fn entry=>let val(i,v)=force entry
         in pair(force(A.lookup mapping i))v end)(A.associations b))
       val x=backwardSubstitution factors(forwardSubstitution factors revised)
   in A.amap(fn x=>mul x scalar)(A.ixmap bnds(fn i=>force(A.lookup mapping i))x)end
