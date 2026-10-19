 type realArray=real A.array
 type segment=int*real F.seq
 type block=realArray*segment A.array
 fun unusedEq _ _=raise Fail"unexpected equality on an array with no default"
 fun appendSequences a b=cell(F.append(force a)(force b))
 fun boolEq a b=force a=force b
 fun dropWhile predicate values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then dropWhile predicate rest else values)
 fun init values=F.defer(fn()=>case force values of F.Nil=>raise Empty|F.Cons(x,rest)=>
   if null rest then F.empty()else F.cons(x,init rest))
 fun segmentEq a b=let val(i,xs)=force a val(j,ys)=force b
   in i=j andalso listEq eq xs ys end
 val pressureElementMatrix=
   let
     fun entry p q(area,(a,b))=
       let fun nth(a,b,c)index=case index of 1=>a|2=>b|_=>c
       in mul(ff1(nth a p)(nth a q)(nth b p)(nth b q))area end
     val rows=List.tabulate(3,fn p=>A.listArray(1,3)
       (F.fromList(List.tabulate(3,fn q=>entry(p+1)(q+1)))))
   in A.listArray(1,3)(F.fromList rows)end
 fun orderedMatrix total(elementFactors:elementFactor A.array)pressureSteer fixed=
   let
     val bnds=(1,total) val extended=(0,total)
     fun intListEq a b=listEq intEq(force a)(force b)
     fun realAssociationEq a b=let val(i,x)=force a val(j,y)=force b in i=j andalso eq x y end
     fun realAssociationsEq a b=listEq realAssociationEq(force a)(force b)
     val contributions=A.flatMap(fn e=>
       let val factors=A.lookup elementFactors(force e)
           val pairs=A.zip(range 1 3)(force(A.lookup pressureSteer(force e)))
       in A.flatMap(fn entry=>let val(ii,i)=force entry
             val row=force(A.lookup pressureElementMatrix(force ii))
           in map(fn column=>let val(jj,j)=force column
               val value=D.delay(fn()=>force(force(A.lookup row(force jj))(force factors)))
             in pair(force i)(cell(singleton(pair(force j)value)))end)
               (F.filter(fn(_,j)=>force j<=force i)pairs)end)pairs end)
       (range(#1(A.bounds elementFactors))(#2(A.bounds elementFactors)))
     val temporary=A.accumArray realAssociationsEq appendSequences(cell(F.empty()))bnds contributions
     val assembled=A.listArray bnds(map(fn i=>cell(A.accumArray eq add zero(1,force i)
       (force(A.lookup temporary(force i)))))(range 1 total))
     val oldMatrix=A.update unusedEq assembled(map(fn i=>D.delay(fn()=>
       let val row=force(A.lookup assembled(force i))
           val revised=A.update eq row(singleton(pair(force i)(mul(A.lookup row(force i))large)))
       in(force i,cell revised)end))fixed)
     val oldRows=A.accumArray intListEq appendSequences(cell(F.empty()))bnds
       (A.flatMap(fn i=>let
           val indices=map(fn entry=>cell(#1(force entry)))(A.sparseAssociations(force(A.lookup oldMatrix(force i))))
           val mirror=map(fn j=>pair(force j)(cell(singleton i)))(F.filter(fn j=>force i<>j)indices)
         in F.cons(pair(force i)(cell indices),mirror)end)(range 1 total))
     fun inverse mapping=A.array extended(map(fn entry=>let val(i,j)=force entry
       in pair(force j)(cell i)end)(A.associations mapping))
     val minToOld=A.listArray extended(F.cons(cell 0,minDegree oldRows))
     val oldToMin=inverse minToOld
     fun getColumns oldIndex mapping=
       let val i=A.lookup mapping oldIndex
       in F.filter(fn j=>j<=force i)
          (map(fn j=>A.lookup mapping(force j))(force(A.lookup oldRows oldIndex)))end
     fun children tree=A.accumArray intListEq appendSequences(cell(F.empty()))extended
       (map(fn entry=>let val(i,j)=force entry in pair(force j)(cell(singleton(cell i)))end)(A.associations tree))
     fun allRows i ancestors parents=if i>total then parents else
       let
         fun root k old=let val next=force(A.lookup old k)
           in if next=0 orelse next=i then(k,old)
             else root next(A.update intEq old(singleton(pair k(cell i))))end
         fun connections values result=case force values of F.Nil=>result|F.Cons(k,rest)=>
           let val(rs,ancestors)=result val(r,revised)=root(force k)ancestors
               val newParent=pair r(cell i)
               val next=if force(A.lookup revised r)<>0 then(rs,revised)
                 else(F.cons(newParent,rs),A.update intEq revised(singleton newParent))
           in connections rest next end
         val(rss,revised)=connections
           (F.filter(fn k=>k<>i)(getColumns(force(A.lookup minToOld i))oldToMin))
           (F.empty(),ancestors)
       in F.append(allRows(i+1)revised parents)rss end
     val minimumTree=A.defArray intEq bnds(cell 0)
       (allRows 1(A.defArray intEq bnds(cell 0)(F.empty()))(F.empty()))
     val childTable=children minimumTree
     fun postorder result values=case force values of F.Nil=>result|F.Cons(r,rest)=>
       let val(reorder,label)=postorder result(force(A.lookup childTable(force r)))
       in postorder(F.cons(pair(force r)(cell label),reorder),label+1)rest end
     val minToNew=A.array extended(F.cons(pair 0(cell 0),#1(postorder(F.empty(),1)(force(A.lookup childTable 0)))))
     val oldToNew=A.amap(fn i=>A.lookup minToNew(force i))oldToMin
     val newToOld=inverse oldToNew
     val newTree=A.array bnds(map(fn entry=>let val(i,j)=force entry
       in pair(force(A.lookup minToNew i))(A.lookup minToNew(force j))end)(A.associations minimumTree))
     val blockEnds=map(fn entry=>cell(#1(force entry)))
       (F.filter(fn(i,j)=>force j<>i+1)(A.associations newTree))
     val blockBounds=A.zip(F.cons(cell 1,map(fn i=>cell(force i+1))(init blockEnds)))blockEnds
     fun getValue i j=D.delay(fn()=>
       let val oldI=force(A.lookup newToOld i) val oldJ=force(A.lookup newToOld j)
       in if oldI<oldJ then force(A.lookup(force(A.lookup oldMatrix oldJ))oldI)
         else force(A.lookup(force(A.lookup oldMatrix oldI))oldJ)end)
     fun findNonzero i=
       let fun walk j flags=if j>i orelse j=0 orelse force(A.lookup flags j)then flags
             else walk(force(A.lookup newTree j))(A.update boolEq flags(singleton(pair j(cell true))))
           fun loop values flags=case force values of F.Nil=>flags|F.Cons(j,rest)=>loop rest(walk(force j)flags)
       in loop(getColumns(force(A.lookup newToOld i))oldToNew)(A.defArray boolEq(1,i)(cell false)(F.empty()))end
     fun firstNonzero(lo,hi)flags=
       let fun loop j=if j>hi orelse force(A.lookup flags j)then j else loop(j+1)
       in loop lo end
     val initial=A.listArray(1,length blockEnds)(map(fn bounds=>D.delay(fn()=>
       let val(lo,hi)=let val(a,b)=force bounds in(force a,force b)end
           val diagonal=A.listArray(lo,hi)(map(fn i=>getValue(force i)(force i))(range lo hi))
           val nonempty=F.filter(fn(_,j)=>j<=hi)
             (map(fn i=>pair(force i)(firstNonzero(lo,hi)(findNonzero(force i))))(range(lo+1)total))
           val off=A.defArray segmentEq(lo+1,total)(cell(hi+1,F.empty()))
             (map(fn entry=>let val(i,j)=force entry
               in pair i(cell(j,map(fn column=>getValue i(force column))(range j(Int.min(hi,i-1)))))end)nonempty)
       in(diagonal,off)end))blockBounds)
   in(initial,oldToNew)end
