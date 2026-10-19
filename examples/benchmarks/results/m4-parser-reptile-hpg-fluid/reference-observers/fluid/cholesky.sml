 fun calOneElement(start,values)(_,segment)old=D.delay(fn()=>
   let val(other,rest)=force segment
   in if null rest then force old else
     let val maximum=Int.max(other,start)
     in force(sub old(listInnerProd(F.drop(maximum-other)rest)(F.drop(maximum-start)values)))end end)
 fun calOneSegment segments(old,off)=F.defer(fn()=>if null segments then F.empty()else
   let val(_,values)=force old val off=force off
   in zipWith(fn segment=>fn old=>calOneElement off(force segment)old)segments values end)
 fun matchPairs xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,xt)=>(case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>
      let val(i,a)=force x val(j,b)=force y
      in if i<j then matchPairs xt ys else if j<i then matchPairs xs yt
        else F.cons(pair i(cell(a,b)),matchPairs xt yt)end))
 fun cholesky(initial:block A.array)=
   let
     fun factor old index=
       let val j=force index
           val current=A.lookup old j
           val bnds=A.bounds(#1(force current)) val(lo,hi)=bnds
           fun previous k=D.delay(fn()=>
             let val off= #2(force(A.lookup old(force k)))
             in(force k,cell(F.filter(fn(i,_)=>lo<=i andalso i<=hi)(A.associations off)))end)
           val predecessors=map previous(range 1(j-1))
           fun update block previous=D.delay(fn()=>
             let val(diag,off)=force block val(k,segments)=force previous val segments=force segments
                 val newDiagonal=A.accum eq sub diag
                   (map(fn segment=>let val(i,value)=force segment val(_,vs)=force value
                     in pair i(listInnerProd vs vs)end)
                    (F.filter(fn(_,segment)=>not(null(#2(force segment))))segments))
                 val pairs=matchPairs(A.sparseAssociations off)
                   (A.sparseAssociations(#2(force(A.lookup old k))))
                 val newOff=A.update segmentEq off(map(fn entry=>
                   let val(i,matched)=force entry val(a,b)=force matched
                       val(start,_)=force a
                   in pair i(cell(start,calOneSegment(F.drop(start-lo)segments)(a,b)))end)pairs)
             in(newDiagonal,newOff)end)
           val first=A.foldLeft update current predecessors
           val result=L.delay(fn()=>
             let val(diag,off)=force first
                 fun build entries(diagonal,offsets)=case force entries of F.Nil=>(diagonal,offsets)
                   |F.Cons(entry,rest)=>
                     let val(i,value)=force entry val(start,values)=force value
                         fun scan oldValues diags segments accumulated=case force oldValues of F.Nil=>accumulated
                           |F.Cons(old,ot)=>(case force diags of F.Nil=>accumulated|F.Cons(d,dt)=>
                             case force segments of F.Nil=>accumulated|F.Cons(segment,st)=>
                               let val next=divide(calOneElement(start,accumulated)(force segment)old)d
                               in scan ot dt st(F.append accumulated(singleton next))end)
                         val newOff=scan values(F.drop(start-lo)diagonal)(F.drop(start-lo)offsets)(F.empty())
                         fun newDiagonal()=sqrt(sub(A.lookup diag i)(listInnerProd newOff newOff))
                         val nextOffsets=F.append offsets(singleton(pair i(cell(start,newOff))))
                     in build rest(if i<=hi then F.append diagonal(singleton(newDiagonal()))else diagonal,nextOffsets)end
             in build(A.sparseAssociations off)
                 (singleton(sqrt(A.lookup diag lo)),singleton(pair lo(cell(lo+1,F.empty()))))end)
           val diagonal=A.listArray bnds(F.defer(fn()=> #1(L.force result)))
           val off=A.update segmentEq(#2(force first))(tail(F.defer(fn()=> #2(L.force result))))
       in A.update unusedEq old(singleton(pair j(cell(diagonal,off))))end
     val result=A.foldLeft(fn old=>fn index=>cell(factor(force old)index))(cell initial)
       (range(#1(A.bounds initial))(#2(A.bounds initial)))
   in force result end
