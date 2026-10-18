 type lr1Item=int D.t*int D.t*NameSet.set
 fun unionItems left right=C.defer(fn()=>
   case L.force right of C.Nil=>left
    |C.Cons(y,ys)=>(case L.force left of C.Nil=>right
      |C.Cons(x,xs)=>
        let val(rule,dot,la)=L.force x val(rule',dot',la')=L.force y
            val order=case Int.compare(D.force rule,D.force rule')of EQUAL=>Int.compare(D.force dot,D.force dot')|order=>order
        in case order of LESS=>C.cons(x,unionItems xs right)
         |GREATER=>C.cons(y,unionItems left ys)
         |EQUAL=>C.cons(L.delay(fn()=>(rule,dot,NameSet.union la la')),unionItems xs ys)end))
 fun subtractItem old item result=C.defer(fn()=>
   case L.force old of C.Nil=>C.cons(item,result)
    |C.Cons(value,rest)=>
      let val(rule,dot,la)=L.force value val(rule',dot',la')=L.force item
          val order=case Int.compare(D.force rule',D.force rule)of EQUAL=>Int.compare(D.force dot',D.force dot)|order=>order
      in case order of LESS=>C.cons(item,result)
       |GREATER=>subtractItem rest item result
       |EQUAL=>let val remaining=NameSet.difference la' la
                in if NameSet.null remaining then result
                   else C.cons(L.delay(fn()=>(rule,dot,remaining)),result)end end)
 fun subtractItems items old=cFoldr(fn item=>fn result=>subtractItem old item result)(C.empty())items
 fun controlFromFinite values=C.defer(fn()=>case D.force values of F.Nil=>C.empty()
   |F.Cons(value,rest)=>C.cons(L.delay(fn()=>value),controlFromFinite rest))
 fun closure1 grammar first initial=
   let val threshold=firstTerm grammar
       fun expand(rule,dot,lookahead)=C.defer(fn()=>
         let val(_,rhs,_,_)=D.force(lookupProdNo grammar(D.force rule))
         in case D.force(F.drop(D.force dot)rhs)of F.Nil=>C.empty()
          |F.Cons(symbol,beta)=>
            if D.force symbol>=3 andalso D.force symbol<threshold then
              let val terms=NameSet.fold(fn token=>fn rest=>
                       NameSet.union(first(F.append beta(singleton(D.delay(fn()=>token)))))rest)
                         NameSet.empty lookahead
                  val rules=controlFromFinite(lookupProdsOfName grammar(D.force symbol))
              in cMap(fn rule=>(rule,D.delay(fn()=>0),terms))rules end
            else C.empty()end)
       fun update(old,new)=
         let val combined=unionItems new old
             val additions=cMap expand new
             val merged=cFoldr(fn values=>fn rest=>unionItems(L.force values)rest)(C.empty())additions
         in(combined,subtractItems merged combined)end
       fun done(_,new)_=cNull new
       val(result,_)=mkClosure done update(C.empty(),initial)
   in result end
