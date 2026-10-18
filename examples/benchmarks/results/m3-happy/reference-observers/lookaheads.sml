 type spontaneous=int L.delay*lr0Item*NameSet.set
 type propagation=lr0Item*int L.delay*lr0Item
 type lookaheadEntries=(lr0Item*NameSet.set)C.seq
 fun sameItem((rule,dot),(rule',dot'))=
   D.force rule=D.force rule' andalso D.force dot=D.force dot'
 fun cFlatMap f values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
   |C.Cons(value,rest)=>C.append(f(L.force value))(cFlatMap f rest))
 fun cEnumerate start values=
   let fun loop i values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
         |C.Cons(value,rest)=>C.cons(L.delay(fn()=>(i,L.force value)),loop(i+1)rest))
   in loop start values end
 fun cToList values=case L.force values of C.Nil=>[]
   |C.Cons(value,rest)=>L.force value::cToList rest
 fun controlFromItems set=
   let fun loop stream=C.defer(fn()=>case L.force stream of ItemSet.Nil=>C.empty()
         |ItemSet.Cons(item,rest)=>C.cons(L.delay(fn()=>item),loop rest))
   in loop(ItemSet.toAscList set)end
 fun lookupGoto token gotos=
   case L.force gotos of C.Nil=>NONE
    |C.Cons(value,rest)=>let val(name,index)=L.force value
       in if D.force token=D.force name then SOME index else lookupGoto token rest end
 fun containsViaList wanted set=
   let fun loop stream=case L.force stream of NameSet.Nil=>false
         |NameSet.Cons(value,rest)=>value=wanted orelse loop rest
   in loop(NameSet.toAscList set)end
 fun startLookahead grammar partial=if D.force partial then 1 else eof grammar
 fun propLookaheads grammar states first=
   let fun perState(i,(set,gotos))=
         let fun perItem original=
               let val(rule,dot)=original
                   val closed=L.delay(fn()=>closure1 grammar first
                       (C.cons(L.delay(fn()=>(rule,dot,NameSet.singleton 2)),C.empty())))
                   val values=C.defer(fn()=>L.force closed)
                   fun spontaneous(rule,dot,terms)=C.defer(fn()=>
                     case findRule grammar(D.force rule)(D.force dot)of NONE=>C.empty()
                      |SOME token=>(case lookupGoto token gotos of NONE=>raise Fail"spontaneous"
                        |SOME destination=>
                           let val realTerms=NameSet.filter(fn n=>n<>2)terms
                           in if NameSet.null realTerms then C.empty()
                              else C.cons(L.delay(fn()=>(destination,
                                   (rule,D.delay(fn()=>D.force dot+1)),realTerms)),C.empty())end))
                   fun propagated(rule,dot,terms)=C.defer(fn()=>
                     if not(containsViaList 2 terms)then C.empty()
                     else case findRule grammar(D.force rule)(D.force dot)of NONE=>C.empty()
                      |SOME token=>(case lookupGoto token gotos of NONE=>raise Fail"propagated"
                        |SOME destination=>C.cons(L.delay(fn()=>(original,destination,
                           (rule,D.delay(fn()=>D.force dot+1)))),C.empty())))
               in(cFlatMap spontaneous values,cFlatMap propagated values)end
             val perItems=cMap perItem(controlFromItems set)
             val startSpont=cMap(fn(index,start)=>
                 let val(_,_,_,partial)=D.force start
                     val terms=L.delay(fn()=>L.force(NameSet.singleton(startLookahead grammar partial)))
                 in(L.delay(fn()=>index),(D.delay(fn()=>index),D.delay(fn()=>0)),terms)end)
                 (cEnumerate 0(controlFromFinite(starts grammar)))
             val spontaneous=C.append startSpont(cFlatMap(fn(s,_)=>s)perItems)
             val propagated=cFlatMap(fn(_,p)=>p)perItems
         in(spontaneous,(i,propagated))end
       val results=cMap perState(cEnumerate 0 states)
       val spontaneous=cFlatMap(fn(s,_)=>s)results
       val propagated=A.array(0,cLength states-1)(fn()=>
          List.map(fn(_,entry)=>let val(i,p)=entry in(i,L.delay(fn()=>p))end)(cToList results))
   in(spontaneous,propagated)end
 fun foldLookahead item rest=C.defer(fn()=>
   case L.force rest of C.Nil=>C.cons(item,C.empty())
    |C.Cons(value,tail)=>
      let val(i,key,terms)=L.force item val(j,key',terms')=L.force value
      in if L.force i=L.force j andalso sameItem(key,key')then
           C.cons(L.delay(fn()=>(i,key,NameSet.union terms terms')),tail)
         else if L.force i<L.force j then C.cons(item,rest)
         else C.cons(value,foldLookahead item tail)end)
 fun addLookahead key terms entries=C.defer(fn()=>
   case L.force entries of C.Nil=>C.cons(L.delay(fn()=>(key,terms)),C.empty())
    |C.Cons(value,rest)=>let val(key',old)=L.force value
       in if sameItem(key,key')then C.cons(L.delay(fn()=>(key,NameSet.union terms old)),rest)
          else C.cons(value,addLookahead key terms rest)end)
 fun getNewPrime item old result=C.defer(fn()=>
   case L.force old of C.Nil=>C.cons(item,result)
    |C.Cons(value,rest)=>
      let val(i,key,terms)=L.force item val(key',existing)=L.force value
      in if sameItem(key,key')then
           let val delta=NameSet.filter(fn n=>not(NameSet.member n existing))terms
           in if NameSet.null delta then result
              else C.cons(L.delay(fn()=>(i,key,delta)),result)end
         else getNewPrime item rest result end)
 fun calcLookaheads nStates spontaneous propagated=
   L.delay(fn()=>
     let val work:lookaheadEntries Array.array=Array.array(nStates+1,C.empty())
         fun getNew items accum=
           case L.force items of C.Nil=>accum
            |C.Cons(item,rest)=>
              let val(i,_,_)=L.force item
                  val snapshot=Array.sub(work,L.force i)
                  val next=C.defer(fn()=>getNewPrime item snapshot accum)
              in getNew rest next end
         fun add entries=
           case L.force entries of C.Nil=>()
            |C.Cons(value,rest)=>
              let val(i,key,terms)=L.force value
                  val index=L.force i val snapshot=Array.sub(work,index)
                  val _=Array.update(work,index,addLookahead key terms snapshot)
              in add rest end
         fun propagate new=
           if cNull new then()
           else let
             fun itemTargets(j,key,terms)=
               cFlatMap(fn(source,i,target)=>
                 if sameItem(key,source)then C.cons(L.delay(fn()=>(i,target,terms)),C.empty())
                 else C.empty())(A.sub propagated(L.force j))
             val items=cFlatMap itemTargets new
             val next=getNew items(C.empty())
             val _=add new
           in propagate next end
         val initial=cFoldr foldLookahead(C.empty())spontaneous
         val _=propagate initial
         val frozen=Vector.tabulate(nStates+1,fn i=>
             let val value=Array.sub(work,i)in L.delay(fn()=>value)end)
     in A.ArrayNode(0,nStates,frozen)end)
 fun mergeLookaheadInfo lookaheads states=
   cMap(fn(index,(items,gotos))=>
     let fun intoItem(original as(rule,dot))=
           let val terms=L.delay(fn()=>
                 let fun collect values=
                       case L.force values of C.Nil=>[]
                        |C.Cons(value,rest)=>let val(key,set)=L.force value
                             in if sameItem(original,key)then set::collect rest else collect rest end
                 in case collect(A.sub lookaheads index)of []=>L.force NameSet.empty
                    |[set]=>L.force set|_=>raise Fail"mergIntoItem"end)
           in(rule,dot,terms)end
     in(cMap intoItem(controlFromItems items),gotos)end)(cEnumerate 0 states)
