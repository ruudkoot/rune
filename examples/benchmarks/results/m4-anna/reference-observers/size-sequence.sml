
 fun recoverRelation equal leq values=
   let fun insert value others=F.defer(fn()=>if any(fn other=>leq other value)others then others
         else F.cons(value,filter(fn other=>not(leq value other))others))
       fun above value=foldRight insert(F.empty())
           (filter(fn other=>leq value other andalso not(equal value other))values)
   in map(fn value=>pair value(above value))values end
 fun shortestPath equal roads start finish=
   let fun aux considered=F.defer(fn()=>if null considered then panic"Dijkstra failed"else
         let fun minimum left right=let val(_,a,_)=force left val(_,b,_)=force right
               in if less a b then left else right end
             val bestEntry=foldLeft minimum(head considered)(tail considered)
             val(best,cost,_)=force bestEntry
             val outgoing=map(fn road=>let val(_,target,localCost)=force road
                 in triple target(add localCost cost)best end)
                 (filter(fn road=>let val(source,_,_)=force road in equal source best end)roads)
             val without=filter(fn entry=>let val(place,_,_)=force entry in not(equal place best)end)considered
             fun update entry old=F.defer(fn()=>case force old of F.Nil=>singleton entry
               |F.Cons(current,rest)=>let val(place,newCost,back)=force entry
                    val(other,oldCost,oldBack)=force current
                 in if not(equal place other)then F.cons(current,update entry rest)
                    else if leq oldCost newCost then old else F.cons(triple other newCost back,rest)end)
             fun updateAll old new=F.defer(fn()=>case force new of F.Nil=>old
               |F.Cons(entry,rest)=>updateAll(update entry old)rest)
         in if equal best finish then singleton bestEntry
            else F.cons(bestEntry,aux(updateAll without outgoing))end)
       val costs=aux(singleton(triple start(int 0)start))
       fun unlink here=F.defer(fn()=>
         let val entry=head(filter(fn entry=>let val(place,_,_)=force entry in equal place here end)costs)
             val(place,cost,back)=force entry
         in if equal start here then singleton(pair start(int 0))
            else F.cons(pair place cost,unlink back)end)
   in reverse(unlink finish)end
 fun oneSizeSequence table scale domains=
   let val crossed=cell(Lift1 domains)
       val candidates=F.cons(crossed,init(reduceDomain crossed))
       val counted=map(fn d=>pair d(latticeCardinality table d))candidates
       fun collect values=L.delay(fn()=>case force values of F.Nil=>(F.empty(),F.empty())
         |F.Cons(entry,rest)=>let val(d,size)=force entry val MkExInt(n,missing)=force size
              val future=collect rest
              val errors=F.defer(fn()=>F.append missing(#1(L.force future)))
              val sizes=F.cons(pair d(subtract n(int 1)),F.defer(fn()=> #2(L.force future)))
           in(errors,sizes)end)
       val allSizes=collect counted
       val sizes=F.defer(fn()=>let val(errors,sizes)=L.force allSizes
         in if null errors then sizes
            else panic"slMakeOneSequence: no size for domain"end)
       fun equal x y=let val(d,n)=force x val(e,m)=force y
         in equalDomain d e andalso equalInt n m end
       fun leq x y=let val(d,_)=force x val(e,_)=force y in compatible e d end
       val above=recoverRelation equal leq sizes
       val edges=flatMap(fn entry=>let val(from,targets)=force entry
         in map(fn target=>pair from target)targets end)above
       fun absolute value=if less value(int 0)then negative value else value
       val costed=map(fn edge=>let val(from,target)=force edge
            val(_,n)=force from val(_,m)=force target
            val difference=subtract(divide(multiply m(int 10))n)scale
            val factor=divide m(int 10)
         in triple from target(multiply factor(absolute difference))end)edges
   in shortestPath equal costed(last sizes)(head sizes)end
 fun transpose values=F.defer(fn()=>if null values then F.empty()else
   let val rows=filter(fn row=>not(null row))values
   in if null rows then F.empty()else F.cons(map head rows,transpose(map tail rows))end)
 fun takeWhile predicate values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,takeWhile predicate rest)else F.empty())
 fun sizeSequence table scale groups low high=L.delay(fn()=>
   let fun clean value=let val(sized,_)=force value val(domain,size)=force sized
         in case force domain of Lift1 domains=>pair size domains|_=>raise Match end
       val initial=map(fn domains=>reverse(map clean(oneSizeSequence table scale domains)))groups
       fun minimum a b=if less a b then a else b
       fun maximum a b=if less a b then b else a
       val limit=foldLeft minimum(length(head initial))(map length(tail initial))
       val equalLengths=map(fn values=>reverse(take limit values))initial
       val together=transpose equalLengths
       val maxima=map(fn values=>
           let val numbers=map(fn value=> #1(force value))values
           in foldLeft maximum(head numbers)(tail numbers)end)together
       val lowDrop=minimum(length(takeWhile(fn n=>less n low)maxima))(subtract limit(int 1))
       val limit2=subtract limit lowDrop
       val adjusted=drop lowDrop together
       val maxima2=reverse(drop lowDrop maxima)
       val highDrop=minimum(length(takeWhile(fn n=>less high n)maxima2))(subtract limit2(int 1))
       val used=subtract limit2 highDrop
   in(take used adjusted,drop used adjusted)end)
