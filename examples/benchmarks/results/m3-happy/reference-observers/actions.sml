 datatype lrAction=LRShift of int D.t*priority D.t|LRReduce of int D.t*priority D.t
   |LRAccept|LRFail|LRMustFail|LRMultiple of lrAction F.seq*lrAction D.t
 datatype gotoAction=Goto of int D.t|NoGoto
 val failAction=D.delay(fn()=>LRFail)
 val acceptAction=D.delay(fn()=>LRAccept)
 val noGoto=D.delay(fn()=>NoGoto)
 fun samePriority a b=case(D.force a,D.force b)of(No,No)=>true
   |(Prio(_,n),Prio(_,m))=>D.force n=D.force m|_=>false
 fun sameAction a b=
   case(D.force a,D.force b)of
     (LRShift(n,p),LRShift(m,q))=>D.force n=D.force m andalso samePriority p q
    |(LRReduce(n,p),LRReduce(m,q))=>D.force n=D.force m andalso samePriority p q
    |(LRAccept,LRAccept)=>true|(LRFail,LRFail)=>true|(LRMustFail,LRMustFail)=>true
    |(LRMultiple(xs,x),LRMultiple(ys,y))=>sameActions xs ys andalso sameAction x y
    |_=>false
 and sameActions xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xs),F.Cons(y,ys))=>sameAction x y andalso sameActions xs ys|_=>false
 fun nubActions values=
   let fun member value []=false|member value(x::xs)=sameAction value x orelse member value xs
       fun loop values seen=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>if member value seen then loop rest seen
            else F.cons(value,loop rest(value::seen)))
   in loop values[]end
 fun resolve left right=D.delay(fn()=>
   let val a=D.force left val b=D.force right
       fun multiple loser winner=LRMultiple(singleton loser,winner)
   in case(a,b)of(LRFail,_)=>b|(_,LRFail)=>a
     |(LRMustFail,_)=>LRMustFail|(_,LRMustFail)=>LRMustFail
     |_=>if sameAction left right then a
       else case(a,b)of
          (LRAccept,_)=>LRAccept|(_,LRAccept)=>LRAccept
         |(LRMultiple(as',x),LRMultiple(bs,y))=>
            if sameAction x y then LRMultiple(nubActions(F.append as' bs),x)
            else(case D.force(resolve x y)of
              LRMultiple(cs,winner)=>
                let val losses=F.append as'(F.append bs cs)
                in if sameAction winner x then LRMultiple(nubActions(F.cons(y,losses)),x)
                   else if sameAction winner y then LRMultiple(nubActions(F.cons(x,losses)),y)
                   else raise Fail"failed invariant in resolve"end
             |other=>other)
         |(LRMultiple _,_)=>D.force(resolve left(D.delay(fn()=>LRMultiple(F.empty(),right))))
         |(_,LRMultiple _)=>D.force(resolve(D.delay(fn()=>LRMultiple(F.empty(),left)))right)
         |(LRShift _,LRReduce _)=>D.force(resolve right left)
         |(LRReduce(_,p),LRShift(_,q))=>
            (case(D.force p,D.force q)of
              (No,_)=>multiple left right|(_,No)=>multiple left right
             |(Prio(assoc,n),Prio(_,m))=>
                if D.force n<D.force m then b
                else if D.force n>D.force m then a
                else(case D.force assoc of LeftAssoc=>a|RightAssoc=>b|NonAssoc=>LRMustFail))
         |(LRReduce(r,p),LRReduce(s,q))=>
            (case(D.force p,D.force q)of
              (No,_)=>multiple left right|(_,No)=>multiple left right
             |(Prio(_,n),Prio(_,m))=>
                if D.force n<D.force m then b
                (* Preserve the source's redundant j>i guard. *)
                else if D.force m>D.force n then a
                else if D.force r<D.force s then multiple right left else multiple left right)
         |_=>raise Fail"confict in resolve"
   end)
 fun genGotoTable grammar states=L.delay(fn()=>L.force(
   let val low=firstNonterm grammar val high=firstTerm grammar-1
       fun row(_,gotos)=A.array(low,high)(fn()=>
         List.map(fn n=>(n,L.delay(fn()=>D.delay(fn()=>case lookupGoto(D.delay(fn()=>n))gotos of
              NONE=>NoGoto|SOME index=>Goto(D.delay(fn()=>L.force index))))))
           (List.filter(fn n=>n>=low andalso n<=high)(F.toList(nonterminals grammar))))
   in A.array(0,cLength states-1)(fn()=>List.map(fn(i,value)=>(i,L.delay(fn()=>row value)))
          (cToList(cEnumerate 0 states)))end))
 fun genActionTable grammar first states=L.delay(fn()=>L.force(
   let val threshold=firstTerm grammar
       val terms=terminals grammar
       val nStarts=length(starts grammar)
       val priorities=priorities grammar
       val bounds=(F.nth terms 0,F.nth terms(length terms-1))
       fun possible gotos(rule,pos,la)=C.defer(fn()=>
         case findRule grammar(D.force rule)(D.force pos)of
           SOME token=>
             if D.force token>=threshold orelse D.force token=1 then
               (case lookupGoto token gotos of NONE=>C.empty()
                 |SOME index=>
                    let val p=case lookupInt(D.force token)priorities of NONE=>noPriority|SOME p=>p
                    in C.cons(L.delay(fn()=>(token,D.delay(fn()=>LRShift(D.delay(fn()=>L.force index),p)))),C.empty())end)
             else C.empty()
          |NONE=>if D.force rule<nStarts then
              let val(_,_,_,partial)=F.nth(starts grammar)(D.force rule)
              in C.cons(L.delay(fn()=>(D.delay(fn()=>startLookahead grammar partial),acceptAction)),C.empty())end
            else let val(_,_,_,p)=D.force(lookupProdNo grammar(D.force rule))
                     fun stream values=C.defer(fn()=>case L.force values of NameSet.Nil=>C.empty()
                       |NameSet.Cons(value,rest)=>C.cons(L.delay(fn()=>
                          (D.delay(fn()=>value),D.delay(fn()=>LRReduce(rule,p)))),stream rest))
                 in stream(NameSet.toAscList la)end)
       fun row(items,gotos)=
         let val expanded=closure1 grammar first items
             val entries=cFlatMap(possible gotos)expanded
         in A.accum(fn old=>fn value=>L.delay(fn()=>resolve(L.force old)(L.force value)))
              (L.delay(fn()=>failAction))bounds(fn()=>
                List.map(fn(token,action)=>(D.force token,L.delay(fn()=>action)))(cToList entries))end
   in A.array(0,cLength states-1)(fn()=>List.map(fn(i,value)=>(i,L.delay(fn()=>row value)))
          (cToList(cEnumerate 0 states)))end))
 fun arrayElements array=
   let fun loop i high=C.defer(fn()=>if i>high then C.empty()
         else C.cons(L.delay(fn()=>A.sub array i),loop(i+1)high))
   in C.defer(fn()=>let val(low,high)=A.bounds array in loop low high end)end
 fun countConflicts action=
   let fun countOne value remaining=L.delay(fn()=>
         case D.force(L.force value)of
           LRMultiple(losers,winner)=>
             (case D.force losers of F.Nil=>raise Fail"bad conflict representation"
              |_=>let val(sr,rr)=L.force remaining
                   in case D.force winner of LRShift _=>(L.delay(fn()=>L.force sr+1),rr)
                    |LRReduce _=>(sr,L.delay(fn()=>L.force rr+1))
                    |_=>raise Fail"bad conflict representation"end)
          |_=>L.force remaining)
       fun countRow row=cFoldr countOne(L.delay(fn()=>(L.delay(fn()=>0),L.delay(fn()=>0))))(arrayElements row)
       val rows=cMap countRow(arrayElements action)
       val counts=cFoldr(fn value=>fn rest=>L.delay(fn()=>
           let val(a,b)=L.force(L.force value)val(c,d)=L.force rest
           in(L.delay(fn()=>L.force a+L.force c),L.delay(fn()=>L.force b+L.force d))end))
           (L.delay(fn()=>(L.delay(fn()=>0),L.delay(fn()=>0))))rows
       val perState=L.delay(fn()=>
         let val(low,high)=A.bounds action
             fun entries i values=case L.force values of C.Nil=>[]
               |C.Cons(value,rest)=>(i,L.delay(fn()=>L.force value))::entries(i+1)rest
             val result=A.array(low,high)(fn()=>entries low rows)
         in L.force result end)
   in(perState,counts)end
