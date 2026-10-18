 fun naturalSortBy cmp values=
    let fun merge xs []=xs|merge [] ys=ys
          |merge(xs as x::xr)(ys as y::yr)=if cmp(x,y)=GREATER then y::merge xs yr else x::merge xr ys
        fun descending a acc(b::bs)=if cmp(a,b)=GREATER then descending b(a::acc)bs
              else((a::acc),b::bs)
          |descending a acc []=(a::acc,[])
        fun ascending a acc(b::bs)=if cmp(a,b)<>GREATER then ascending b(fn tail=>acc(a::tail))bs
              else(acc[a],b::bs)
          |ascending a acc []=(acc[a],[])
        fun sequences(a::b::rest)=let val(run,tail)=if cmp(a,b)=GREATER
              then descending b[a]rest else ascending b(fn tail=>a::tail)rest
            in run::sequences tail end
          |sequences []=[]|sequences xs=[xs]
        fun pairs(a::b::rest)=merge a b::pairs rest|pairs xs=xs
        fun all []=[]|all[x]=x|all xs=all(pairs xs)
    in all(sequences values)end

 fun sortFinite cmp values=F.defer(fn()=>F.fromList(naturalSortBy cmp(F.toList values)))
 fun flatMap f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.append(f(D.force value))(flatMap f rest))
 fun appendMany values=flatMap(fn value=>value)values
 fun enumerate start values=
   let fun loop index values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>F.cons(D.delay(fn()=>(D.delay(fn()=>index),value)),loop(index+1)rest))
   in loop start values end
 fun length values=F.length values
 fun range low high=F.defer(fn()=>if low>high then F.empty()
      else F.cons(D.delay(fn()=>low),range(low+1)high))
 fun memberInt value values=case D.force values of F.Nil=>false
   |F.Cons(x,rest)=>D.force x=value orelse memberInt value rest
 fun memberText value values=case D.force values of F.Nil=>false
   |F.Cons(x,rest)=>sameText value(D.force x)orelse memberText value rest
 fun lookupInt value pairs=case D.force pairs of F.Nil=>NONE
   |F.Cons(pair,rest)=>let val(key,item)=D.force pair
        in if D.force key=value then SOME item else lookupInt value rest end
 fun lookupText value pairs=case D.force pairs of F.Nil=>NONE
   |F.Cons(pair,rest)=>let val(key,item)=D.force pair
        in if sameText key value then SOME item else lookupText value rest end
 fun priorityOf level dir=D.delay(fn()=>case dir of
     TokenNonassoc _=>Prio(D.delay(fn()=>NonAssoc),D.delay(fn()=>level))
    |TokenRight _=>Prio(D.delay(fn()=>RightAssoc),D.delay(fn()=>level))
    |TokenLeft _=>Prio(D.delay(fn()=>LeftAssoc),D.delay(fn()=>level))|_=>internal())
