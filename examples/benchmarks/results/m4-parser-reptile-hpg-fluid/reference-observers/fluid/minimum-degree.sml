 fun mergeLine xs ys=F.defer(fn()=>case force xs of F.Nil=>F.append xs ys
   |F.Cons(x,xt)=>(case force ys of F.Nil=>F.append xs ys|F.Cons(y,yt)=>
      if force x=force y then F.cons(x,mergeLine xt yt)
      else if force x<force y then F.cons(x,mergeLine xt ys)
      else F.cons(y,mergeLine xs yt)))
 fun removeList xs ys=F.defer(fn()=>case force xs of F.Nil=>ys
   |F.Cons(x,xt)=>(case force ys of F.Nil=>ys|F.Cons(y,yt)=>
      if force x=force y then removeList xt yt
      else if force x<force y then removeList xt ys
      else F.cons(y,removeList xs yt)))
 fun mergeLines lines=case force lines of F.Nil=>raise Empty|F.Cons(x,rest)=>
   force(A.foldLeft(fn a=>fn b=>cell(mergeLine(force a)(force b)))x rest)
 fun equalIntLists a b=listEq intEq(force a)(force b)
 fun uniqueLists values=let
     fun memberList x seen=case force seen of F.Nil=>false|F.Cons(y,rest)=>
       equalIntLists x y orelse memberList x rest
     fun loop values seen=F.defer(fn()=>case force values of F.Nil=>F.empty()
       |F.Cons(x,rest)=>if memberList x seen then loop rest seen
         else F.cons(x,loop rest(F.cons(x,seen))))
   in loop values(F.empty())end
 fun minDegree oldRows=
   let
     fun appendLists a b=cell(F.append(force a)(force b))
     val initial=A.accumArray equalIntLists appendLists(cell(F.empty()))(A.bounds oldRows)
       (map(fn p=>let val(i,row)=force p in pair(length(force row))(cell(singleton(cell i)))end)
         (A.associations oldRows))
     fun find counts cliques processed result=
       let val remaining=A.sparseAssociations counts
       in if null remaining then result else
         let val(_,pivots)=force(head remaining) val pivot=force(head(force pivots))
             fun getCols index cliques=removeList processed
               (mergeLines(F.cons(A.lookup oldRows index,
                 F.filter(fn clique=>member index clique)cliques)))
             val newColumns=F.filter(fn value=>value<>pivot)(getCols pivot cliques)
             val done=mergeLine processed(singleton(cell pivot))
             val nextResult=F.append result(singleton(cell pivot))
             fun removeCliques values removed=case force values of F.Nil=>removed
               |F.Cons(clique,rest)=>
                 let val(left,right)=A.partition(fn n=>pivot<force n)(force clique)
                     val without=L.delay(fn()=>F.append left(tail right))
                     val keep=if null right orelse force(head right)<>pivot then true
                       else case force(L.force without)of F.Nil=>false|F.Cons(_,tail)=>not(null tail)
                 in removeCliques rest(if keep then F.cons(
                      if null right orelse force(head right)<>pivot then clique else cell(L.force without),removed)else removed)end
             val removed=removeCliques cliques(F.empty())
             val nextCliques=uniqueLists(F.cons(cell newColumns,removed))
             fun updateCounts values updates=case force values of F.Nil=>updates
               |F.Cons(r,rest)=>
                 let val count=length(getCols(force r)(F.cons(cell newColumns,cliques)))-1
                 in updateCounts rest(F.cons(pair count(cell(singleton r)),updates))end
             val updates=updateCounts newColumns(F.empty())
             val changed=mergeLines(F.cons(cell(singleton(cell pivot)),
               map(fn p=> #2(force p))updates))
             val oldCounts=map(fn p=>let val(i,rows)=force p
               in pair i(cell(removeList changed(force rows)))end)(A.sparseAssociations counts)
             val nextCounts=A.accumArray equalIntLists
               (fn a=>fn b=>cell(mergeLine(force a)(force b)))(cell(F.empty()))(A.bounds counts)
               (F.append oldCounts updates)
         in find nextCounts nextCliques done nextResult end
       end
   in find initial(F.empty())(F.empty())(F.empty())end
