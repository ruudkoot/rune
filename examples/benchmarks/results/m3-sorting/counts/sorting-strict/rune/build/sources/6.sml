(* Eight nofib sorting algorithms; preserve their order, ties and tree shapes. *)
functor BenchSortingFn(D : BENCH_SUSPEND) =
struct
 structure Q=BenchCellSequenceFn(D)
 datatype 'a tree=Tip | Branch of 'a D.t * 'a tree D.t * 'a tree D.t
 datatype 'a tree2=Tip2 | Twig2 of 'a D.t | Branch2 of 'a D.t * 'a tree2 D.t * 'a tree2 D.t
 fun tip()=D.delay(fn()=>Tip)
 fun tip2()=D.delay(fn()=>Tip2)
 fun singleton x=Q.cons x(Q.empty())
 fun filter predicate xs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>if predicate(D.force x)then Q.Cons(x,filter predicate rest)else D.force(filter predicate rest))
 fun reverse xs=
   let fun loop input result=case D.force input of Q.Nil=>result
         | Q.Cons(x,rest)=>loop rest(Q.cons x result)
   in loop xs(Q.empty())end
 fun quickSort compare xs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>D.force(Q.append(quickSort compare(filter(fn y=>compare(y,D.force x)<>GREATER)rest))
       (Q.cons x(quickSort compare(filter(fn y=>compare(y,D.force x)=GREATER)rest)))))
 fun partition predicate xs=D.delay(fn()=>case D.force xs of Q.Nil=>(Q.empty(),Q.empty())
   | Q.Cons(x,rest)=>
       let val parts=partition predicate rest
           fun left()=D.delay(fn()=>D.force(#1(D.force parts)))
           fun right()=D.delay(fn()=>D.force(#2(D.force parts)))
       in if predicate(D.force x)then(Q.cons x(left()),right())else(left(),Q.cons x(right()))end)
 fun quickSort2 compare xs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>
       let val parts=partition(fn y=>compare(D.force x,y)<>LESS)rest
           val lo=D.delay(fn()=>D.force(#1(D.force parts)))
           val hi=D.delay(fn()=>D.force(#2(D.force parts)))
       in D.force(Q.append(quickSort2 compare lo)(Q.cons x(quickSort2 compare hi)))end)
 fun quickerSort compare xs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>case D.force rest of Q.Nil=>Q.Cons(x,Q.empty())
     | _=>let fun split lo hi input=case D.force input of
                 Q.Nil=>D.force(Q.append(quickerSort compare lo)(Q.cons x(quickerSort compare hi)))
               | Q.Cons(y,tail)=>if compare(D.force y,D.force x)<>GREATER then split(Q.cons y lo)hi tail
                   else split lo(Q.cons y hi)tail
          in split(Q.empty())(Q.empty())rest end)
 fun insertSort compare xs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>
       let fun trins rev sorted input=case D.force sorted of
                 Q.Nil=>(case D.force input of Q.Nil=>D.force(reverse rev)
                   | Q.Cons(y,ys)=>trins(Q.empty())(Q.append(reverse rev)(singleton y))ys)
               | Q.Cons(a,tail)=>(case D.force input of Q.Nil=>D.force(Q.append(reverse rev)sorted)
                   | Q.Cons(y,ys)=>if compare(D.force a,D.force y)=LESS then trins(Q.cons a rev)tail input
                     else trins(Q.empty())(Q.append(reverse rev)(Q.cons y sorted))ys)
       in trins(Q.empty())(singleton x)rest end)
 fun toTree compare x tree=D.delay(fn()=>case D.force tree of Tip=>Branch(x,tip(),tip())
   | Branch(y,left,right)=>if compare(D.force x,D.force y)<>GREATER
       then Branch(y,toTree compare x left,right)else Branch(y,left,toTree compare x right))
 fun makeTree compare xs=D.delay(fn()=>case D.force xs of Q.Nil=>Tip
   | Q.Cons(x,rest)=>D.force(toTree compare x(makeTree compare rest)))
 fun readTree tree=D.delay(fn()=>case D.force tree of Tip=>Q.Nil
   | Branch(x,left,right)=>D.force(Q.append(readTree left)(Q.cons x(readTree right))))
 fun treeSort compare xs=readTree(makeTree compare xs)
 fun toTree2 compare x tree=D.delay(fn()=>case D.force tree of Tip2=>Twig2 x
   | Twig2 y=>if compare(D.force x,D.force y)<>GREATER then Branch2(y,D.delay(fn()=>Twig2 x),tip2())
       else Branch2(y,tip2(),D.delay(fn()=>Twig2 x))
   | Branch2(y,left,right)=>if compare(D.force x,D.force y)<>GREATER
       then Branch2(y,toTree2 compare x left,right)else Branch2(y,left,toTree2 compare x right))
 fun makeTree2 compare xs=D.delay(fn()=>case D.force xs of Q.Nil=>Tip2
   | Q.Cons(x,rest)=>D.force(toTree2 compare x(makeTree2 compare rest)))
 fun readTree2 tree=D.delay(fn()=>case D.force tree of Tip2=>Q.Nil | Twig2 x=>Q.Cons(x,Q.empty())
   | Branch2(x,left,right)=>D.force(Q.append(readTree2 left)(Q.cons x(readTree2 right))))
 fun treeSort2 compare xs=readTree2(makeTree2 compare xs)
 fun toHeap compare k x tree=D.delay(fn()=>case D.force tree of Tip=>Branch(x,tip(),tip())
   | Branch(y,left,right)=>
       if compare(D.force x,D.force y)<>GREATER andalso k mod 2=1 then Branch(x,toHeap compare(k div 2)y left,right)
       else if compare(D.force x,D.force y)<>GREATER then Branch(x,left,toHeap compare(k div 2)y right)
       else if k mod 2=1 then Branch(y,toHeap compare(k div 2)x left,right)
       else Branch(y,left,toHeap compare(k div 2)x right))
 fun heap compare k xs=D.delay(fn()=>case D.force xs of Q.Nil=>Tip
   | Q.Cons(x,rest)=>D.force(toHeap compare k x(heap compare(k+1)rest)))
 fun mix compare left right=D.delay(fn()=>case D.force left of Tip=>D.force right
   | Branch(x,l1,r1)=>case D.force right of Tip=>D.force left
     | Branch(y,l2,r2)=>if compare(D.force x,D.force y)<>GREATER
         then Branch(x,mix compare l1 r1,right)else Branch(y,left,mix compare l2 r2))
 fun clear compare tree=D.delay(fn()=>case D.force tree of Tip=>Q.Nil
   | Branch(x,left,right)=>Q.Cons(x,clear compare(mix compare left right)))
 fun heapSort compare xs=clear compare(heap compare 0 xs)
 fun runsplit compare run xs=D.delay(fn()=>case D.force run of
       Q.Nil=>(case D.force xs of Q.Nil=>Q.Nil | Q.Cons(x,rest)=>D.force(runsplit compare(singleton x)rest))
     | Q.Cons(r,rs)=>(case D.force xs of Q.Nil=>Q.Cons(Q.value run,Q.empty())
       | Q.Cons(x,rest)=>case D.force rs of
           Q.Nil=>if compare(D.force x,D.force r)=GREATER then D.force(runsplit compare(Q.cons r(singleton x))rest)
             else if compare(D.force x,D.force r)<>GREATER then D.force(runsplit compare(Q.cons x run)rest)
             else Q.Cons(Q.value run,runsplit compare(singleton x)rest)
         | _=>if compare(D.force x,D.force r)<>GREATER then D.force(runsplit compare(Q.cons x run)rest)
             else Q.Cons(Q.value run,runsplit compare(singleton x)rest)))
 fun merge compare xs ys=D.delay(fn()=>case D.force xs of Q.Nil=>D.force ys
   | Q.Cons(x,rest)=>case D.force ys of Q.Nil=>D.force xs
     | Q.Cons(y,tail)=>if compare(D.force x,D.force y)=EQUAL then Q.Cons(x,Q.cons y(merge compare rest tail))
       else if compare(D.force x,D.force y)=LESS then Q.Cons(x,merge compare rest ys)
       else Q.Cons(y,merge compare xs tail))
 fun mergeLists compare runs=D.delay(fn()=>case D.force runs of Q.Nil=>Q.Nil
   | Q.Cons(run,rest)=>D.force(merge compare(D.force run)(mergeLists compare rest)))
 fun mergeSort compare xs=mergeLists compare(runsplit compare(Q.empty())xs)
 fun mangle compare xs=heapSort compare(reverse(insertSort compare(reverse(mergeSort compare(reverse
   (quickSort compare(reverse(quickSort2 compare(reverse(quickerSort compare(reverse
     (treeSort compare(reverse(treeSort2 compare xs))))))))))))))
end
