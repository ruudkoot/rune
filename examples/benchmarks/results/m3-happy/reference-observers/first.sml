 structure NameSet=BenchHappySetFn(type item=int val compare=Int.compare)
 fun setFromNames values=
   let fun stream values=L.delay(fn()=>case D.force values of F.Nil=>NameSet.Nil
         |F.Cons(value,rest)=>NameSet.Cons(D.force value,stream rest))
   in NameSet.fromStream(stream values)end
 fun namesFromSet set=
   let fun loop stream=F.defer(fn()=>case L.force stream of NameSet.Nil=>F.empty()
         |NameSet.Cons(value,rest)=>F.cons(D.delay(fn()=>value),loop rest))
   in loop(NameSet.toAscList set)end
 fun incEmpty set=
   let fun loop stream=case L.force stream of NameSet.Nil=>false
         |NameSet.Cons(value,rest)=>value=0 orelse loop rest
   in loop(NameSet.toAscList set)end
 fun joinSymSets first values=L.delay(fn()=>
   case D.force values of F.Nil=>L.force(NameSet.singleton 0)
    |F.Cons(value,rest)=>
      let val head=first(D.force value)
      in if incEmpty head then
           L.force(NameSet.union(NameSet.filter(fn n=>n<>0)head)(joinSymSets first rest))
         else L.force head end)
 fun mkClosure equivalent update initial=
   let fun loop value=
         let val next=L.delay(fn()=>update value)
         in if equivalent value next then value else loop(L.force next)end
   in loop initial end
 fun foldBalanced combine values=
   let fun pass(a::b::c::d::rest)=combine(combine a b)(combine c d)::pass rest
         |pass(a::b::rest)=combine a b::pass rest
         |pass values=values
       fun loop []=raise Fail"can't reduce an empty list using foldb"
         |loop[value]=value
         |loop values=loop(pass values)
   in loop values end
 fun mkFirst grammar=
   let val environment=L.delay(fn()=>
         let val threshold=firstTerm grammar
             val ntNames=nonterminals grammar
             fun next env=
               let fun firstSymbol symbol=
                     if symbol=1 orelse symbol>=threshold then NameSet.singleton symbol
                     else case lookupInt symbol env of SOME set=>set
                       |NONE=>raise Fail"attempted FIRST(e) :-("
                   fun result name=L.delay(fn()=>
                     if name>=threshold then L.force(NameSet.singleton name)
                     else
                      let fun ruleFirst rule=L.delay(fn()=>
                             let val(_,rhs,_,_)=D.force(lookupProdNo grammar rule)
                             in L.force(joinSymSets firstSymbol rhs)end)
                          val sets=List.map ruleFirst(F.toList(lookupProdsOfName grammar name))
                      in L.force(foldBalanced NameSet.union sets)end)
               in F.map(fn(name,_) =>(name,result(D.force name)))env end
             fun equivalent a b=
               let fun same a b=case(D.force a,D.force b)of(F.Nil,F.Nil)=>true
                     |(F.Cons(x,xs),F.Cons(y,ys))=>
                        let val(n,s)=D.force x val(m,t)=D.force y
                        in D.force n=D.force m andalso NameSet.equal s t andalso same xs ys end
                     |_=>false
               in same a(L.force b)end
             val initial=F.map(fn name=>(D.delay(fn()=>name),NameSet.empty))ntNames
         in mkClosure equivalent next initial end)
       fun firstSymbol name=L.delay(fn()=>
         case lookupInt name(L.force environment)of NONE=>L.force(NameSet.singleton name)
          |SOME set=>L.force set)
   in joinSymSets firstSymbol end
