 fun andWith predicate xs ys=case(force xs,force ys)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xt),F.Cons(y,yt))=>predicate x y andalso andWith predicate xt yt
   |_=>panic"myAndWith2: unequal lists"
 fun foldRight1 f xs=D.delay(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>
   if null rest then force x else force(f x(foldRight1 f rest)))
 fun partialFrontier count frontier arguments:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force frontier
       fun trim value=let val MkFrel routes=force value in cell(MkFrel(drop count routes))end
       val ones=insertionSort compareFrel(minimal belowFrel(map trim
         (filter(fn value=>let val MkFrel routes=force value
            in andWith belowRoute(take count routes)arguments end)ones)))
       val zeros=insertionSort compareFrel(maximal belowFrel(map trim
         (filter(fn value=>let val MkFrel routes=force value
            in andWith belowRoute arguments(take count routes)end)zeros)))
   in if leq count arity then Min1Max0(subtract arity count,ones,zeros)else panic"apPap_2"end)
 fun partialRepresentation rep arguments:representation=D.delay(fn()=>case force rep of
    RepTwo frontier=>RepTwo(partialFrontier(length arguments)frontier arguments)
   |Rep1(low,highs)=>Rep1(partialFrontier(length arguments)low arguments,
        map(fn rep=>partialRepresentation rep arguments)highs)
   |Rep2(low,middle,highs)=>Rep2(partialFrontier(length arguments)low arguments,
        partialFrontier(length arguments)middle arguments,map(fn rep=>partialRepresentation rep arguments)highs))
 fun constantRepresentation rep:route=D.delay(fn()=>case force rep of
    RepTwo frontier=>let val Min1Max0(arity,ones,zeros)=force frontier
      in if less(int 0)arity then Rep rep
         else if null ones andalso not(null zeros)then Zero
         else if not(null ones)andalso null zeros then One else panic"apPapConst(1)"end
   |Rep1(low,highs)=>let val Min1Max0(arity,ones,zeros)=force low
      in if less(int 0)arity then Rep rep
         else if null ones andalso not(null zeros)then Stop1
         else if not(null ones)andalso null zeros then Up1(map constantRepresentation highs)
         else panic"apPapConst(2)"end
   |Rep2(low,middle,highs)=>let val Min1Max0(arity,ones,zeros)=force low
          val Min1Max0(_,middleOnes,middleZeros)=force middle
      in if less(int 0)arity then Rep rep
         else if null ones andalso not(null zeros)then Stop2
         else if null middleOnes andalso not(null middleZeros)then Up2
         else if not(null middleOnes)andalso null middleZeros then UpUp2(map constantRepresentation highs)
         else panic"apPapConst(3)"end)
 fun applyRoute function arguments:route=D.delay(fn()=>case force function of Rep rep=>
   force(constantRepresentation(partialRepresentation rep arguments))|_=>raise Match)
 fun evaluateAbstract(expression:hexpr):hexpr=D.delay(fn()=>case force expression of
    HVar _=>panic"aeEval(1)"|HLam _=>panic"aeEval(2)"|HTable _=>panic"aeEval(3)"
   |HPoint _=>force expression
   |HMeet expressions=>HPoint(foldRight1 joinRoute(map evaluateConstant expressions))
   |HVAp(f,args)=>(case force f of HPoint function=>HPoint(applyRoute function(map evaluateConstant args))
       |_=>panic"aeEval(4)")
   |HApp(f,arg)=>(case force f of HTable table=>
         force(evaluateAbstract(sureLookup equalRoute table"aeEval(5)"(evaluateConstant arg)))
      |HApp _=>force(evaluateAbstract(cell(HApp(evaluateAbstract f,arg))))
      |HPoint _=>force(evaluateAbstract(cell(HVAp(f,singleton arg))))
      |_=>panic"aeEval(4)"))
 and evaluateConstant expression:route=D.delay(fn()=>case force(evaluateAbstract expression)of
    HPoint point=>force point|_=>panic"aeEvalConst")
 fun substituteAbstract rho(expression:hexpr):hexpr=D.delay(fn()=>case force expression of
    HVar n=>force(sureLookup equalName rho"aeSubst"n)
   |HPoint _=>force expression|HLam _=>panic"aeSubst(1)"
   |HMeet expressions=>HMeet(map(substituteAbstract rho)expressions)
   |HTable entries=>HTable(mapSecond(substituteAbstract rho)entries)
   |HApp(a,b)=>HApp(substituteAbstract rho a,substituteAbstract rho b)
   |HVAp(f,args)=>HVAp(substituteAbstract rho f,map(substituteAbstract rho)args))
 fun evaluateExact expression arguments:route=D.delay(fn()=>case force expression of
    HLam(variables,body)=>force(evaluateConstant(substituteAbstract(zipExact pair variables arguments)body))
   |_=>raise Match)
 fun makeAbstractMeet bottom expressions:hexpr=D.delay(fn()=>case force expressions of
    F.Nil=>force bottom|F.Cons(x,rest)=>if null rest then force x else HMeet expressions)
