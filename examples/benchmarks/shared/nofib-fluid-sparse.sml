(* Persistent binary radix tries, preserving the source representation. *)
functor BenchFluidSparseFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 datatype 'a trieNode=Null|Leaf of 'a D.t|Fork of 'a trieNode L.delay*'a trieNode L.delay
 type 'a trie='a trieNode L.delay
 datatype 'a arrayNode=Array of (int*int)*int*'a D.t option*'a trie
 type 'a array='a arrayNode L.delay
 fun cell v=D.delay(fn()=>v)
 fun empty()=F.empty()
 fun singleton v=F.cons(v,F.empty())
 fun nilTrie()=L.delay(fn()=>Null)
 fun leaf v=L.delay(fn()=>Leaf v)
 fun head values=case D.force values of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail values=F.defer(fn()=>case D.force values of F.Nil=>raise Empty|F.Cons(_,rest)=>rest)
 fun null values=case D.force values of F.Nil=>true|_=>false
 fun map f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
    |F.Cons(x,rest)=>F.cons(D.delay(fn()=>D.force(f x)),map f rest))
 fun zip xs ys=F.defer(fn()=>case D.force xs of F.Nil=>F.empty()
    |F.Cons(x,xt)=>(case D.force ys of F.Nil=>F.empty()
      |F.Cons(y,yt)=>F.cons(cell(x,y),zip xt yt)))
 fun flatMap f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
    |F.Cons(x,rest)=>F.append(f x)(flatMap f rest))
 fun range lo hi=F.defer(fn()=>if lo>hi then F.empty()
   else F.cons(cell lo,range(lo+1)hi))
 fun foldLeft f initial values=D.delay(fn()=>
   let fun loop acc values=case D.force values of F.Nil=>D.force acc
     |F.Cons(x,rest)=>loop(D.delay(fn()=>D.force(f acc x)))rest
   in loop initial values end)
 fun all predicate values=case D.force values of F.Nil=>true
   |F.Cons(x,rest)=>predicate x andalso all predicate rest
 fun listSize(lo,hi)=if lo<=hi then hi-lo+1 else 0
 fun height bounds=if #1 bounds<= #2 bounds
   then Real.ceil(Math.ln(Real.fromInt(listSize bounds))/Math.ln 2.0)else 0
 fun power n=if n=0 then 1 else 2*power(n-1)
 fun treeSize bounds=if #1 bounds<= #2 bounds then power(height bounds)else 0
 fun inRange(lo,hi)i=lo<=i andalso i<=hi
 fun out()=raise Fail"s_array: index out of range!"
 fun undef()=raise Fail"s_array: value not defined!"
 fun multi()=raise Fail"s_array: multiple value definitions!"
 fun fork left right=L.delay(fn()=>case L.force left of Null=>
     (case L.force right of Null=>Null|_=>Fork(left,right))|_=>Fork(left,right))
 fun partition predicate values=
   let val result=L.delay(fn()=>case D.force values of F.Nil=>(F.empty(),F.empty())
         |F.Cons(x,rest)=>let val next=partition predicate rest
           in if predicate x then(F.cons(x,#1 next),#2 next)
             else(#1 next,F.cons(x,#2 next))end)
   in(F.defer(fn()=> #1(L.force result)),F.defer(fn()=> #2(L.force result)))end
 fun mapIndices offset associations=map(fn p=>
   let val(i,v)=D.force p in cell(i-offset,v)end)associations
 fun convert offset associations=map(fn p=>
   let val(i,v)=D.force p in cell(i-offset,leaf v)end)associations
 fun check bounds associations=all(fn p=>let val(index,_)=D.force p in inRange bounds index end)associations
 fun genTrie size associations=L.delay(fn()=>case D.force associations of F.Nil=>Null
   |F.Cons(p,rest)=>if size=1 then
       if null rest then L.force(#2(D.force p))else multi()
     else let val half=size div 2
          val(left,right)=partition(fn p=> #1(D.force p)<half)associations
       in L.force(fork(genTrie half left)(genTrie half(mapIndices half right)))end)
 fun group tries=F.defer(fn()=>case D.force tries of F.Nil=>F.empty()
   |F.Cons(a,rest)=>(case D.force rest of F.Nil=>singleton(cell(fork(D.force a)(nilTrie())))
     |F.Cons(b,rest)=>F.cons(cell(fork(D.force a)(D.force b)),group rest)))
 fun genList level tries=L.delay(fn()=>case D.force tries of F.Nil=>Null
   |F.Cons(t,rest)=>if level=0 andalso null rest then L.force(D.force t)
       else L.force(genList(level-1)(group tries)))
 fun array bounds associations=L.delay(fn()=>
   if check bounds associations then Array(bounds,treeSize bounds,NONE,
      genTrie(treeSize bounds)(convert(#1 bounds)associations))else out())
 fun defArray eq bounds default associations=L.delay(fn()=>
   if check bounds associations then Array(bounds,treeSize bounds,SOME default,
      genTrie(treeSize bounds)(convert(#1 bounds)
        (F.filter(fn(_,v)=>not(eq v default))associations)))else out())
 fun listArray bounds values=L.delay(fn()=>Array(bounds,treeSize bounds,NONE,
   genList(height bounds)(map(fn v=>cell(leaf v))(F.take(listSize bounds)values))))
 fun defListArray eq bounds default values=L.delay(fn()=>Array(bounds,treeSize bounds,SOME default,
   genList(height bounds)(map(fn v=>cell(if eq v default then nilTrie()else leaf v))
      (F.take(listSize bounds)values))))
 fun bounds a=case L.force a of Array(bounds,_,_,_)=>bounds
 fun findLeaf trie size index=case L.force trie of Fork(left,right)=>
     let val half=size div 2 in if index<half then findLeaf left half index
        else findLeaf right half(index-half)end
    |_=>trie
 fun lookup a index=D.delay(fn()=>let val(bnds,size,default,trie)=
       case L.force a of Array p=>p
     in if not(inRange bnds index)then out()else
       case L.force(findLeaf trie size(index- #1 bnds))of Leaf v=>D.force v
        |_=>case default of SOME v=>D.force v|NONE=>undef()end)
 fun elements a=let val(bnds,size,default,trie)=case L.force a of Array p=>p
       fun fallback()=D.delay(fn()=>case default of SOME v=>D.force v|NONE=>undef())
       fun flatten n size trie=F.defer(fn()=>case L.force trie of
         Fork(left,right)=>let val half=size div 2
           in F.append(flatten(Int.min(half,n))half left)(flatten(Int.max(0,n-half))half right)end
        |Null=>map(fn _=>fallback())(range 1 n)
        |Leaf v=>singleton v)
   in flatten(listSize bnds)size trie end
 fun associations a=map(fn pair=>
   let val(i,v)=D.force pair in cell(D.force i,v)end)(zip(range(#1(bounds a))(#2(bounds a)))(elements a))
 fun sparseAssociations a=let val(bnds,size,_,trie)=case L.force a of Array p=>p
       fun flatten offset size trie=F.defer(fn()=>case L.force trie of
         Fork(left,right)=>let val half=size div 2
           in F.append(flatten offset half left)(flatten(offset+half)half right)end
        |Null=>F.empty()|Leaf v=>singleton(cell(offset,v)))
   in flatten(#1 bnds)size trie end
 fun update eq a associations=L.delay(fn()=>
   let val(bnds,size,default,trie)=case L.force a of Array p=>p
       fun convertValue p=let val(i,v)=D.force p
         in cell(i,case default of NONE=>leaf v
           |SOME d=>if eq v d then nilTrie()else leaf v)end
       fun loop trie size associations=L.delay(fn()=>if null associations then L.force trie else
         case L.force trie of Fork(left,right)=>let val half=size div 2
             val(xs,ys)=partition(fn p=> #1(D.force p)<half)associations
           in L.force(fork(loop left half xs)(loop right half(mapIndices half ys)))end
          |Null=>L.force(genTrie size associations)
          |Leaf _=>if null(tail associations)then L.force(#2(D.force(head associations)))else multi())
       val converted=case default of NONE=>convert(#1 bnds)associations
         |SOME _=>mapIndices(#1 bnds)(map convertValue associations)
   in if check bnds associations then Array(bnds,size,default,loop trie size converted)else out()end)
 fun accum eq f a associations=L.delay(fn()=>
   let val(bnds,size,default,trie)=case L.force a of Array p=>p
       fun fallback()=D.delay(fn()=>case default of SOME v=>D.force v|NONE=>undef())
       fun genLeaf initial associations=
         let val value=foldLeft f initial(map(fn p=>let val(_,value)=D.force p in value end)associations)
         in case default of SOME d=>if eq value d then nilTrie()else leaf value|NONE=>leaf value end
       fun gen size associations=L.delay(fn()=>if null associations then Null
         else if size=1 then L.force(genLeaf(fallback())associations)
         else let val half=size div 2 val(xs,ys)=partition(fn p=> #1(D.force p)<half)associations
           in L.force(fork(gen half xs)(gen half(mapIndices half ys)))end)
       fun loop trie size associations=L.delay(fn()=>if null associations then L.force trie else
         case L.force trie of Fork(left,right)=>let val half=size div 2
             val(xs,ys)=partition(fn p=> #1(D.force p)<half)associations
           in L.force(fork(loop left half xs)(loop right half(mapIndices half ys)))end
          |Null=>L.force(gen size associations)|Leaf v=>L.force(genLeaf v associations))
   in if check bnds associations then Array(bnds,size,default,loop trie size(mapIndices(#1 bnds)associations))else out()end)
 fun accumArray eq f initial bnds associations=
   accum eq f(L.delay(fn()=>Array(bnds,treeSize bnds,SOME initial,nilTrie())))associations
 fun amap f a=L.delay(fn()=>let val(bnds,size,default,trie)=case L.force a of Array p=>p
       fun replace trie=L.delay(fn()=>case L.force trie of Null=>Null|Leaf v=>Leaf(f v)
         |Fork(left,right)=>L.force(fork(replace left)(replace right)))
   in Array(bnds,size,Option.map f default,replace trie)end)
 fun ixmap bnds f a=L.delay(fn()=>let val(old,size,default,trie)=case L.force a of Array p=>p
     val tries=map(fn i=>cell(findLeaf trie size(f(D.force i)- #1 old)))(range(#1 bnds)(#2 bnds))
   in Array(bnds,treeSize bnds,default,genList(height bnds)tries)end)
end
