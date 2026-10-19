 fun filter predicate xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,filter predicate rest)else filter predicate rest)
 fun zipWith f xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()|F.Cons(x,xt)=>
   case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>F.cons(D.delay(fn()=>force(f x y)),zipWith f xt yt))
 fun zip xs ys=zipWith pair xs ys
 fun zipExact f xs ys=F.defer(fn()=>case(force xs,force ys)of(F.Nil,F.Nil)=>F.empty()
   |(F.Cons(x,xt),F.Cons(y,yt))=>F.cons(D.delay(fn()=>force(f x y)),zipExact f xt yt)
   |_=>panic"myZipWith2: unequal lists")
 fun zip3Exact f xs ys zs=F.defer(fn()=>case(force xs,force ys,force zs)of(F.Nil,F.Nil,F.Nil)=>F.empty()
   |(F.Cons(x,xt),F.Cons(y,yt),F.Cons(z,zt))=>F.cons(D.delay(fn()=>force(f x y z)),zip3Exact f xt yt zt)
   |_=>panic"myZipWith3: unequal lists")
 fun foldLeft f initial xs=D.delay(fn()=>
   let fun loop acc xs=case force xs of F.Nil=>force acc
        |F.Cons(x,rest)=>loop(D.delay(fn()=>force(f acc x)))rest
   in loop initial xs end)
 fun foldRight f initial xs=D.delay(fn()=>case force xs of F.Nil=>force initial
   |F.Cons(x,rest)=>force(f x(foldRight f initial rest)))
 fun all predicate xs=case force xs of F.Nil=>true|F.Cons(x,rest)=>predicate x andalso all predicate rest
 fun any predicate xs=case force xs of F.Nil=>false|F.Cons(x,rest)=>predicate x orelse any predicate rest
 fun take n xs=F.defer(fn()=>if leq n(int 0)then F.empty()else case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(x,take(subtract n(int 1))rest))
 fun drop n xs=F.defer(fn()=>if leq n(int 0)then xs else case force xs of F.Nil=>F.empty()
   |F.Cons(_,rest)=>drop(subtract n(int 1))rest)
 fun nth xs index=case force xs of F.Nil=>panic"(##) (1)"
   |F.Cons(x,rest)=>if equalInt index(int 0)then x else nth rest(subtract index(int 1))
 fun reverse xs=F.defer(fn()=>let
      fun loop xs acc=case force xs of F.Nil=>acc|F.Cons(x,rest)=>loop rest(F.cons(x,acc))
   in loop xs(F.empty())end)
 fun last xs=case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>if null rest then x else last rest
 fun init xs=F.defer(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>
   if null rest then F.empty()else F.cons(x,init rest))
 fun repeat value=let val slot=ref NONE
      fun node()=case !slot of SOME root=>root|NONE=>
        let val root=L.delay(fn()=>C.Cons(L.delay(fn()=>value),node()))
        in slot:=SOME root;root end
   in node()end
 fun fromControl xs=F.defer(fn()=>case L.force xs of C.Nil=>F.empty()
   |C.Cons(x,rest)=>F.cons(L.force x,fromControl rest))
 fun copy n value=fromControl(C.take(Int.max(0,small n))(repeat value))
 fun intsFrom n=C.defer(fn()=>C.cons(L.delay(fn()=>n),intsFrom(add n(int 1))))
 fun intsFromTo lo hi=F.defer(fn()=>if less hi lo then F.empty()
   else F.cons(lo,intsFromTo(add lo(int 1))hi))
 fun listVariants xs alternatives=F.defer(fn()=>case(force xs,force alternatives)of(F.Nil,F.Nil)=>F.empty()
   |(F.Cons(x,xt),F.Cons(rs,rst))=>
      F.append(map(fn replacement=>F.cons(replacement,xt))rs)
        (map(fn suffix=>F.cons(x,suffix))(listVariants xt rst))
   |_=>panic"myListVariants: unequal lists")
 (* Source enumerates the first list fastest within each suffix. *)
 fun cartesianProduct xss=F.defer(fn()=>case force xss of F.Nil=>singleton(F.empty())
   |F.Cons(xs,rest)=>flatMap(fn suffix=>map(fn x=>F.cons(x,suffix))xs)(cartesianProduct rest))
 fun mySeq equal value next=if equal value value then next()else raise Match
 fun insertionSort compare xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>
     let fun insert xs=F.defer(fn()=>case force xs of F.Nil=>singleton x
           |F.Cons(y,yt)=>if compare x y<>GREATER then F.cons(x,xs)else F.cons(y,insert yt))
     in insert(insertionSort compare rest)end)
 fun removeDuplicates equal xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>(case force rest of F.Nil=>singleton x|F.Cons(y,yt)=>
       if equal x y then removeDuplicates equal rest else F.cons(x,removeDuplicates equal rest)))
 fun unzip values=
   let val result=L.delay(fn()=>case force values of F.Nil=>(F.empty(),F.empty())
        |F.Cons(pair,rest)=>let val(a,b)=force pair val(xs,ys)=unzip rest
          in(F.cons(a,xs),F.cons(b,ys))end)
   in(F.defer(fn()=> #1(L.force result)),F.defer(fn()=> #2(L.force result)))end
 fun mapFirst f values=map(fn value=>let val(a,b)=force value in pair(f a)b end)values
 fun mapSecond f values=map(fn value=>let val(a,b)=force value in pair a(f b)end)values
 fun mapAccumulate(f:'a D.t->'b D.t->'a D.t*'c D.t)initial values=L.delay(fn()=>case force values of F.Nil=>(initial,F.empty())
   |F.Cons(x,rest)=>let val step=L.delay(fn()=>f initial x)
       val restResult=mapAccumulate f(D.delay(fn()=>force(#1(L.force step))))rest
       val result=F.defer(fn()=> #2(L.force restResult))
     in(D.delay(fn()=>force(#1(L.force restResult))),F.cons(D.delay(fn()=>force(#2(L.force step))),result))end)
 fun interleave separator lists=F.defer(fn()=>case force lists of F.Nil=>F.empty()
   |F.Cons(xs,rest)=>if null rest then xs
     else F.append xs(F.append separator(interleave separator rest)))
 fun set values=cell(MkSet values)
 fun setValues value=case force value of MkSet xs=>xs
 fun setEmpty()=set(F.empty())
 fun setSingleton value=set(singleton value)
 fun setFromList compare values=set(removeDuplicates(fn a=>fn b=>compare a b=EQUAL)(insertionSort compare values))
 fun setUnion compare left right=D.delay(fn()=>
   let fun merge xs ys=F.defer(fn()=>case force xs of F.Nil=>ys
       |F.Cons(x,xt)=>(case force ys of F.Nil=>xs|F.Cons(y,yt)=>
          case compare x y of LESS=>F.cons(x,merge xt ys)
           |EQUAL=>F.cons(x,merge xt yt)|GREATER=>F.cons(y,merge xs yt)))
   in MkSet(merge(setValues left)(setValues right))end)
 fun setIntersection compare left right=D.delay(fn()=>
   let fun merge xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()
       |F.Cons(x,xt)=>(case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>
          case compare x y of LESS=>merge xt ys|EQUAL=>F.cons(x,merge xt yt)|GREATER=>merge xs yt))
   in MkSet(merge(setValues left)(setValues right))end)
 fun setSubtract compare left right=D.delay(fn()=>
   let fun merge xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()
       |F.Cons(x,xt)=>(case force ys of F.Nil=>xs|F.Cons(y,yt)=>
          case compare x y of LESS=>F.cons(x,merge xt ys)|EQUAL=>merge xt yt|GREATER=>merge xs yt))
   in MkSet(merge(setValues left)(setValues right))end)
 fun setMember compare value collection=
   let fun seek xs=case force xs of F.Nil=>false|F.Cons(x,rest)=>
        case compare value x of EQUAL=>true|GREATER=>seek rest|LESS=>false
   in seek(setValues collection)end
 fun setSubset compare left right=all(fn value=>setMember compare value right)(setValues left)
 fun setUnionList compare values=foldLeft(setUnion compare)(setEmpty())values
