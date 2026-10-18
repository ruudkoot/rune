 structure C=X.C
 type lr0Item=int D.t*int D.t
 structure ItemSet=BenchHappySetFn(type item=lr0Item
   val compare=fn((a,b),(c,d))=>case Int.compare(D.force a,D.force c)of
      EQUAL=>Int.compare(D.force b,D.force d)|order=>order)
 fun itemsFromList values=
   let fun stream values=L.delay(fn()=>case D.force values of F.Nil=>ItemSet.Nil
         |F.Cons(value,rest)=>ItemSet.Cons(D.force value,stream rest))
   in ItemSet.fromStream(stream values)end
 fun itemsToList set=
   let fun loop stream=F.defer(fn()=>case L.force stream of ItemSet.Nil=>F.empty()
         |ItemSet.Cons(value,rest)=>F.cons(D.delay(fn()=>value),loop rest))
   in loop(ItemSet.toAscList set)end
 fun findRule grammar rule dot=
   let val(_,rhs,_,_)=D.force(lookupProdNo grammar rule)
   in case D.force(F.drop dot rhs)of F.Nil=>NONE|F.Cons(value,_)=>SOME value end
 fun precalcClosure0 grammar=
   let val info=L.delay(fn()=>
         let val threshold=firstTerm grammar
             fun follow env(name,rules)=
               let fun followRule rule=L.delay(fn()=>
                     case findRule grammar rule 0 of
                       SOME nt=>if D.force nt>=3 andalso D.force nt<threshold then
                         (case lookupInt(D.force nt)env of SOME set=>L.force set|NONE=>raise Fail"followNT")
                         else L.force NameSet.empty
                      |NONE=>L.force NameSet.empty)
                   val additions=NameSet.fold(fn rule=>fn rest=>NameSet.union(followRule rule)rest)NameSet.empty rules
               in(name,NameSet.union additions rules)end
             fun update env=F.map(follow env)env
             fun equal a b=
               let fun loop a b=case(D.force a,D.force b)of(F.Nil,F.Nil)=>true
                     |(F.Cons(x,xs),F.Cons(y,ys))=>
                        let val(n,s)=D.force x val(m,t)=D.force y
                        in D.force n=D.force m andalso NameSet.equal s t andalso loop xs ys end
                     |_=>false
               in loop a(L.force b)end
             val initial=F.map(fn name=>(D.delay(fn()=>name),
                 L.delay(fn()=>L.force(setFromNames(lookupProdsOfName grammar name)))))(nonterminals grammar)
         in mkClosure equal update initial end)
       val expanded=L.delay(fn()=>F.map(fn(name,rules)=>(name,F.map(fn rule=>
           (D.delay(fn()=>rule),D.delay(fn()=>0)))(namesFromSet rules)))(L.force info))
   in fn name=>case lookupInt name(L.force expanded)of NONE=>F.empty()|SOME rules=>rules end
 fun closure0 grammar closures set=
   let val threshold=firstTerm grammar
       fun add(item as(rule,dot))rest=
         let val values=F.cons(D.delay(fn()=>item),F.defer(fn()=>
                case findRule grammar(D.force rule)(D.force dot)of
                  SOME nt=>if D.force nt>=3 andalso D.force nt<threshold then closures(D.force nt)else F.empty()
                 |NONE=>F.empty()))
         in ItemSet.union(itemsFromList values)rest end
   in ItemSet.fold add ItemSet.empty set end
 fun gotoClosure grammar set symbol=
   ItemSet.fold(fn(rule,dot)=>fn rest=>
     let val next=L.delay(fn()=>case findRule grammar(D.force rule)(D.force dot)of
           SOME token=>if D.force token=D.force symbol then
              L.force(ItemSet.singleton(rule,D.delay(fn()=>D.force dot+1)))
             else L.force ItemSet.empty
          |NONE=>L.force ItemSet.empty)
     in ItemSet.union next rest end)ItemSet.empty set
 fun cNull values=case L.force values of C.Nil=>true|_=>false
 fun cLength values=
   let fun loop n values=case L.force values of C.Nil=>n|C.Cons(_,rest)=>loop(n+1)rest
   in loop 0 values end
 fun cReverse values=C.defer(fn()=>
   let fun loop values out=case L.force values of C.Nil=>out
         |C.Cons(value,rest)=>loop rest(C.cons(value,out))
   in loop values(C.empty())end)
 fun cMap f values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
   |C.Cons(value,rest)=>C.cons(L.delay(fn()=>f(L.force value)),cMap f rest))
 fun cZip a b=C.defer(fn()=>case L.force a of C.Nil=>C.empty()
   |C.Cons(x,xs)=>(case L.force b of C.Nil=>C.empty()
      |C.Cons(y,ys)=>C.cons(L.delay(fn()=>(L.force x,L.force y)),cZip xs ys)))
 fun cFoldr f initial values=L.delay(fn()=>case L.force values of C.Nil=>L.force initial
   |C.Cons(value,rest)=>L.force(f value(cFoldr f initial rest)))
 type gotoEdge=int D.t*int L.delay
 type controlGotos=gotoEdge C.seq
 type itemWithGotos=ItemSet.set*controlGotos
 type numbered=int L.delay*controlGotos C.seq*ItemSet.set C.seq
 fun indexInto index wanted values=
   case L.force values of C.Nil=>NONE
    |C.Cons(value,rest)=>if ItemSet.equal wanted(L.force value)then SOME index
       else indexInto(L.delay(fn()=>L.force index+1))wanted rest
 fun genLR0items grammar closures=
   let val tokenValues=F.append(nonterminals grammar)(terminals grammar)
       fun tokens values=C.defer(fn()=>case D.force values of F.Nil=>C.empty()
          |F.Cons(value,rest)=>C.cons(L.delay(fn()=>value),tokens rest))
       val tokenStream=tokens tokenValues
       val startRules=C.defer(fn()=>C.fromList(List.tabulate(length(starts grammar)+1,
           fn rule=>ItemSet.singleton(D.delay(fn()=>rule),D.delay(fn()=>0)))))
       fun update(oldSets,newSets)=
         let val holder=ref(NONE:numbered L.delay option)
             val intGotos=C.defer(fn()=>case !holder of NONE=>raise Fail"uninstalled LR0 numbering knot"
                |SOME result=>let val(_,gotos,_)=L.force result in C.drop 1 gotos end)
             val newOldSets=C.append oldSets(cZip newSets intGotos)
             val count=L.delay(fn()=>cLength newOldSets)
             val itemSets=C.append(cMap(fn(set,_)=>set)oldSets)newSets
             fun row set=
               let val closed=closure0 grammar closures set
                   val all=cMap(fn token=>(token,gotoClosure grammar closed token))tokenStream
               in C.filter(fn(_,next)=>not(ItemSet.null next))all end
             val gotos=cMap row newSets
             fun numberSets rowValue initial=
               let fun loop row state=L.delay(fn()=>
                     case L.force row of C.Nil=>
                       let val(i,gotos,found)=L.force state
                       in(i,C.cons(L.delay(fn()=>C.empty()),gotos),found)end
                      |C.Cons(value,rest)=>
                       let val(token,next)=L.force value
                           val(i,all,found)=L.force state
                           val(g,tail)=case L.force all of C.Cons(g,tail)=>(L.force g,tail)|_=>internal()
                           val existing=C.append itemSets(cReverse found)
                           val index=indexInto(L.delay(fn()=>0))next existing
                           val updated=L.delay(fn()=>case index of
                              SOME j=>(i,C.cons(L.delay(fn()=>C.cons(L.delay(fn()=>(token,j)),g)),tail),found)
                             |NONE=>(L.delay(fn()=>L.force i+1),
                                 C.cons(L.delay(fn()=>C.cons(L.delay(fn()=>(token,i)),g)),tail),
                                 C.cons(L.delay(fn()=>next),found)))
                       in L.force(loop rest updated)end)
               in loop(L.force rowValue)initial end
             val initial=L.delay(fn()=>(count,C.cons(L.delay(fn()=>C.empty()),C.empty()),C.empty()))
             val result=cFoldr numberSets initial gotos
             val _=holder:=SOME result
             val frontier=C.defer(fn()=>let val(_,_,found)=L.force result in cReverse found end)
         in(newOldSets,frontier)end
       fun done(_,newSets)_=cNull newSets
       val(old,_) =mkClosure done update(C.empty(),startRules)
   in old end
