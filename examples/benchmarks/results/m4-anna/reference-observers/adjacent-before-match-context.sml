 fun isSingletonList values=case force values of F.Nil=>false|F.Cons(_,rest)=>null rest
 fun joinZeroFrontiers xs ys=insertionSort compareFrel(maximal belowFrel(flatMap(fn x=>map(meetFrel x)ys)xs))
 fun meetOneFrontiers xs ys=insertionSort compareFrel(minimal belowFrel(flatMap(fn x=>map(joinFrel x)ys)xs))
 fun successors domain point=F.defer(fn()=>case(force domain,force point)of
    (Two,Zero)=>singleton(cell One)|(Two,One)=>F.empty()
   |(Lift1 ds,Stop1)=>singleton(cell(Up1(map bottomRoute ds)))
   |(Lift1 ds,Up1 rs)=>
      if isSingletonList ds andalso isSingletonList rs
      then map(fn r=>cell(Up1(singleton r)))(successors(head ds)(head rs))
      else map(fn values=>cell(Up1 values))(listVariants(map bottomRoute ds)(zipExact successors ds rs))
   |(Lift2 ds,Stop2)=>singleton(cell Up2)
   |(Lift2 ds,Up2)=>singleton(cell(UpUp2(map bottomRoute ds)))
   |(Lift2 ds,UpUp2 rs)=>
      if isSingletonList ds andalso isSingletonList rs
      then map(fn r=>cell(UpUp2(singleton r)))(successors(head ds)(head rs))
      else map(fn values=>cell(UpUp2 values))(listVariants(map bottomRoute ds)(zipExact successors ds rs))
   |(Func _,Rep r)=>map(fn r=>cell(Rep r))(successorRepresentations domain r)
   |_=>raise Match)
 and successorRepresentations domain rep=F.defer(fn()=>case(force domain,force rep)of
    (Func(arguments,result),RepTwo frontier)=>(case force result of Two=>
      let val Min1Max0(arity,_,zeros)=force frontier
      in map(fn x=>cell(RepTwo(makeFrontier arity(singleton x)
           (insertionSort compareFrel(predecessorFrels arguments x)))))zeros end|_=>raise Match)
   |(Func(arguments,result),Rep1(low,highs))=>(case force result of Lift1 targets=>
      let val highDomains=map(uncurryDomain arguments)targets
          val bottoms=map bottomRepresentation highDomains
          val tops=map topRoute arguments
          val lowSucc=successorRepresentations(cell(Func(arguments,cell Two)))(cell(RepTwo low))
          val embedded=flatMap(fn rep=>case force rep of RepTwo f=>singleton(cell(Rep1(f,bottoms)))|_=>F.empty())lowSucc
          val variants=listVariants bottoms(zipExact successorRepresentations highDomains highs)
          val lifted=map(lowerLift tops arguments highDomains)variants
      in minimal belowRepresentation(F.append embedded lifted)end|_=>raise Match)
   |(Func(arguments,result),Rep2(low,middle,highs))=>(case force result of Lift2 targets=>
      let val isoDomain=cell(Func(arguments,cell(Lift1(singleton(cell(Lift1 targets))))))
          val isoRoute=cell(Rep1(low,singleton(cell(Rep1(middle,highs)))))
      in map isoRepresentationInverse(successorRepresentations isoDomain isoRoute)end|_=>raise Match)
   |_=>raise Match)
 and predecessorFrels domains value=
   let val MkFrel routes=force value
   in if isSingletonList domains andalso isSingletonList routes
       then map(fn r=>cell(MkFrel(singleton r)))(predecessors(head domains)(head routes))
      else map(fn values=>cell(MkFrel values))(listVariants(map topRoute domains)(zipExact predecessors domains routes))end
 and successorFrels domains value=
   let val MkFrel routes=force value
   in if isSingletonList domains andalso isSingletonList routes
       then map(fn r=>cell(MkFrel(singleton r)))(successors(head domains)(head routes))
      else map(fn values=>cell(MkFrel values))(listVariants(map bottomRoute domains)(zipExact successors domains routes))end
 and predecessors domain point=F.defer(fn()=>case(force domain,force point)of
    (Two,Zero)=>F.empty()|(Two,One)=>singleton(cell Zero)
   |(Lift1 _,Stop1)=>F.empty()
   |(Lift1 ds,Up1 rs)=>
      if isSingletonList ds andalso isSingletonList rs
        then if isBottomRoute(head rs)then singleton(cell Stop1)
          else map(fn r=>cell(Up1(singleton r)))(predecessors(head ds)(head rs))
        else if all isBottomRoute rs then singleton(cell Stop1)
          else map(fn values=>cell(Up1 values))(listVariants(map topRoute ds)(zipExact predecessors ds rs))
   |(Lift2 _,Stop2)=>F.empty()|(Lift2 _,Up2)=>singleton(cell Stop2)
   |(Lift2 ds,UpUp2 rs)=>
      if isSingletonList ds andalso isSingletonList rs
        then if isBottomRoute(head rs)then singleton(cell Up2)
          else map(fn r=>cell(UpUp2(singleton r)))(predecessors(head ds)(head rs))
        else if all isBottomRoute rs then singleton(cell Up2)
          else map(fn values=>cell(UpUp2 values))(listVariants(map topRoute ds)(zipExact predecessors ds rs))
   |(Func _,Rep r)=>map(fn r=>cell(Rep r))(predecessorRepresentations domain r)|_=>raise Match)
 and predecessorRepresentations domain rep=F.defer(fn()=>case(force domain,force rep)of
    (Func(arguments,result),RepTwo frontier)=>(case force result of Two=>
      let val Min1Max0(arity,ones,_)=force frontier
      in map(fn x=>cell(RepTwo(makeFrontier arity(insertionSort compareFrel(successorFrels arguments x))
          (singleton x))))ones end|_=>raise Match)
   |(Func(arguments,result),Rep1(low,highs))=>(case force result of Lift1 targets=>
      let val highDomains=map(uncurryDomain arguments)targets
          val tops=map topRepresentation highDomains
          val lowDomain=cell(Func(arguments,cell Two))
          val lowTop=topFrontier arguments
          val lowPred=predecessorRepresentations lowDomain(cell(RepTwo low))
          val embedded=flatMap(fn rep=>case force rep of RepTwo f=>singleton(greaterEmbed f targets)|_=>F.empty())lowPred
          val variants=listVariants tops(zipExact predecessorRepresentations highDomains highs)
          val lifted=map(fn reps=>cell(Rep1(lowTop,reps)))variants
      in maximal belowRepresentation(F.append embedded lifted)end|_=>raise Match)
   |(Func(arguments,result),Rep2(low,middle,highs))=>(case force result of Lift2 targets=>
      let val isoDomain=cell(Func(arguments,cell(Lift1(singleton(cell(Lift1 targets))))))
          val isoRoute=cell(Rep1(low,singleton(cell(Rep1(middle,highs)))))
      in map isoRepresentationInverse(predecessorRepresentations isoDomain isoRoute)end|_=>raise Match)
   |_=>raise Match)
 and isoRepresentationInverse rep=D.delay(fn()=>case force rep of Rep1(low,values)=>
      if isSingletonList values then(case force(head values)of Rep1(middle,highs)=>Rep2(low,middle,highs)|_=>raise Match)
        else raise Match|_=>raise Match)
 and lowerLift tops arguments domains reps:representation=D.delay(fn()=>
   let val arity=length tops
       val reduced=zipExact(lowerLiftAux arity tops arguments)domains reps
       val low=case force(foldRight1 joinRepresentation reduced)of RepTwo low=>low|_=>raise Match
   in Rep1(low,reps)end)
 and lowerLiftAux arity tops arguments domain rep=
   case force domain of Func(_,result)=>(case(force result,force rep)of
      (Two,_)=>reduceArity arity tops arguments rep
     |(Lift1 _,Rep1(low,_))=>reduceArity arity tops arguments(cell(RepTwo low))
     |(Lift2 _,Rep2(low,_,_))=>reduceArity arity tops arguments(cell(RepTwo low))
     |_=>raise Match)|_=>raise Match
 and reduceArity arity tops arguments rep:representation=D.delay(fn()=>case force rep of RepTwo frontier=>
   let val Min1Max0(oldArity,ones,zeros)=force frontier
   in if equalInt oldArity arity then force rep else if less arity oldArity then
       let val shortened=map(fn value=>let val MkFrel rs=force value in cell(MkFrel(take arity rs))end)ones
           val zeros=maxZeroFromMinOneAux tops arguments shortened
       in RepTwo(makeFrontier arity shortened zeros)end else raise Match end|_=>raise Match)
 and greaterEmbed frontier targets:representation=cell(Rep1(frontier,map(greaterEmbedAux frontier)targets))
 and greaterEmbedAux frontier domain:representation=D.delay(fn()=>case force domain of Two=>RepTwo frontier
   |Lift1 ds=>Rep1(frontier,map(greaterEmbedAux frontier)ds)
   |Lift2 ds=>Rep2(frontier,frontier,map(greaterEmbedAux frontier)ds)
   |Func(arguments,result)=>let val extended=case force(increaseArity frontier arguments)of RepTwo f=>f|_=>raise Match
       in force(greaterEmbedAux extended result)end)
 and increaseArity frontier domains:representation=D.delay(fn()=>if null domains then RepTwo frontier else
   let val Min1Max0(arity,ones,zeros)=force frontier
       val tops=map topRoute domains val bottoms=map bottomRoute domains
       fun extend suffix value=let val MkFrel rs=force value in cell(MkFrel(F.append rs suffix))end
   in RepTwo(makeFrontier(add arity(length domains))(map(extend bottoms)ones)(map(extend tops)zeros))end)
 and maxZeroFromMinOneAux tops domains ones=
   insertionSort compareFrel(foldRight joinZeroFrontiers(singleton(cell(MkFrel tops)))(map(predecessorFrels domains)ones))
 and minOneFromMaxZeroAux bottoms domains zeros=
   insertionSort compareFrel(foldRight meetOneFrontiers(singleton(cell(MkFrel bottoms)))(map(successorFrels domains)zeros))
