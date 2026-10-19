
 fun returnAction value xin=L.delay(fn()=>(xin,L.delay(fn()=>Success(L.delay value)),F.empty()))
 fun errorAction message xin=L.delay(fn()=>(xin,L.delay(fn()=>Failure message),F.empty()))
 fun forwardInput computation=L.delay(fn()=>let val(xin,_,_)=L.force computation in L.force xin end)
 fun actionValue computation=L.delay(fn()=>let val(_,reply,_)=L.force computation in L.force reply end)
 fun actionOutput computation=F.defer(fn()=>let val(_,_,out)=L.force computation in out end)
 fun outputInput computation=L.delay(fn()=>let val(xin,_)=L.force computation in L.force xin end)
 fun outputText computation=F.defer(fn()=>let val(_,out)=L.force computation in out end)
 fun sequenceOutput first second xin=L.delay(fn()=>
   let val one=first xin
       val two=second(outputInput one)
   in(outputInput two,F.append(outputText one)(outputText two))end)
 fun outputThenAction output action xin=L.delay(fn()=>
   let val one=output xin
       val two=action(outputInput one)
   in(forwardInput two,actionValue two,F.append(outputText one)(actionOutput two))end)
 fun bindTransaction computation next=L.delay(fn()=>
   let val nextComputation=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Success value=>L.force(next value input)
           |Failure message=>L.force(errorAction message input)end)
   in(forwardInput nextComputation,actionValue nextComputation,
       F.append(actionOutput computation)(actionOutput nextComputation))end)
 fun bindAction action next xin=bindTransaction(action xin)next
 fun pairTransactions computation next=L.delay(fn()=>
   let val future=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Failure message=>L.force(errorAction message input)
          |Success value=>
            let val second=next input
                val after=forwardInput second
                val reply=L.delay(fn()=>case L.force(actionValue second)of Failure message=>Failure message
                  |Success other=>Success(L.delay(fn()=>(value,other))))
            in(after,reply,actionOutput second)end end)
   in(forwardInput future,actionValue future,F.append(actionOutput computation)(actionOutput future))end)
 fun pairActions first second xin=pairTransactions(first xin)second
 fun listTransactions computation next=L.delay(fn()=>
   let val future=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Failure message=>L.force(errorAction message input)
          |Success value=>
            let val second=next input
                val after=forwardInput second
                val reply=L.delay(fn()=>case L.force(actionValue second)of Failure message=>Failure message
                  |Success others=>Success(L.delay(fn()=>C.cons(value,C.defer(fn()=>L.force others)))))
            in(after,reply,actionOutput second)end end)
   in(forwardInput future,actionValue future,F.append(actionOutput computation)(actionOutput future))end)
 fun listActions first second xin=listTransactions(first xin)second
 fun handleTransaction computation handler=L.delay(fn()=>
   let val future=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Success value=>L.force(returnAction(fn()=>L.force value)input)
           |Failure message=>L.force(handler message input)end)
   in(forwardInput future,actionValue future,F.append(actionOutput computation)(actionOutput future))end)
 fun handleAction action handler xin=handleTransaction(action xin)handler
 fun outputActions actions xin=L.delay(fn()=>case force actions of F.Nil=>(xin,F.empty())
   |F.Cons(action,rest)=>L.force(sequenceOutput(force action)(outputActions rest)xin))
 fun splitList equal separator values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if equal separator x then F.cons(F.empty(),splitList equal separator rest)
     else case force(splitList equal separator rest)of F.Nil=>singleton(singleton x)
       |F.Cons(part,parts)=>F.cons(F.cons(x,part),parts))
 fun appendLast values value=F.append values(singleton value)
 fun generateUid xin=L.delay(fn()=>
   let val(input,responses,ids)=L.force xin
   in case L.force ids of C.Nil=>raise Match|C.Cons(number,rest)=>
      let val value=L.delay(fn()=>text(Int.toString(force(L.force number))))
          val input=L.delay(fn()=>(input,responses,rest))
      in(input,L.delay(fn()=>Success value),F.empty())end end)
