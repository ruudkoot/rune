 fun defaultDomain expression:domain=D.delay(fn()=>case force expression of DXTwo=>Two|DXVar _=>Two
   |DXLift1 expressions=>if null expressions then Two else Lift1(map defaultDomain expressions)
   |DXLift2 expressions=>if null expressions then Lift1(singleton(cell Two))else Lift2(map defaultDomain expressions)
   |DXFunc(arguments,result)=>Func(map defaultDomain arguments,defaultDomain result))
 fun applyDomainSubstitution substitutions expression:domain=D.delay(fn()=>case force expression of
    DXTwo=>Two|DXVar n=>force(sureLookup equalName substitutions"dxApplySubst"n)
   |DXLift1 expressions=>if null expressions then Two else Lift1(map(applyDomainSubstitution substitutions)expressions)
   |DXLift2 expressions=>if null expressions then Lift1(singleton(cell Two))
      else Lift2(map(applyDomainSubstitution substitutions)expressions)
   |DXFunc(arguments,result)=>Func(map(applyDomainSubstitution substitutions)arguments,applyDomainSubstitution substitutions result))
 fun normalizeDomainExpression expression:dexpr=D.delay(fn()=>case force expression of
    DXTwo=>DXTwo|DXVar n=>DXVar n
   |DXLift1 expressions=>DXLift1(map normalizeDomainExpression expressions)
   |DXLift2 expressions=>DXLift2(map normalizeDomainExpression expressions)
   |DXFunc(arguments,result)=>(case force result of DXFunc(more,result)=>
        force(normalizeDomainExpression(cell(DXFunc(F.append arguments more,result))))
       |_=>DXFunc(map normalizeDomainExpression arguments,normalizeDomainExpression result)))
 fun expressionContainsFunctions expression=case force expression of DXTwo=>false|DXVar _=>false
   |DXLift1 expressions=>any expressionContainsFunctions expressions
   |DXLift2 expressions=>any expressionContainsFunctions expressions|DXFunc _=>true
 fun expressionContainsSubsidiaryFunctions expression=case force expression of DXTwo=>false|DXVar _=>false
   |DXLift1 expressions=>any expressionContainsFunctions expressions
   |DXLift2 expressions=>any expressionContainsFunctions expressions
   |DXFunc(arguments,result)=>any expressionContainsFunctions arguments orelse expressionContainsFunctions result
 type domainDifferenceState=integer*(name*domain)F.seq
 type domainDifferenceResult=(dexpr*domainDifferenceState)L.delay
 fun differenceAux smaller big state:domainDifferenceResult=L.delay(fn()=>case(force smaller,force big)of
    (Two,Two)=>(cell DXTwo,state)
   |(Two,_)=>let val(n,substitutions)=state
        val variable=singleton(cell(Char.chr(small n)))
      in(cell(DXVar variable),(add n(int 1),F.cons(pair variable big,substitutions)))end
   |(Lift1 xs,Lift1 ys)=>let val result=differenceList xs ys state
        val expressions=F.defer(fn()=> #1(L.force result))
        val next= #2(L.force result)
      in(cell(DXLift1 expressions),next)end
   |(Lift2 xs,Lift2 ys)=>let val result=differenceList xs ys state
        val expressions=F.defer(fn()=> #1(L.force result))
      in(cell(DXLift2 expressions),#2(L.force result))end
   |(Func(xs,x),Func(ys,y))=>
      let val args=differenceList xs ys state
          val arguments=F.defer(fn()=> #1(L.force args))
          val result=differenceAux x y(#2(L.force args))
          val expression=D.delay(fn()=>force(#1(L.force result)))
      in(cell(DXFunc(arguments,expression)),#2(L.force result))end
   |_=>panic"dxDiff_aux")
 and differenceList xs ys state=L.delay(fn()=>case(force xs,force ys)of
    (F.Nil,F.Nil)=>(F.empty(),state)
   |(F.Cons(x,xt),F.Cons(y,yt))=>let val first=differenceAux x y state
        val rest=differenceList xt yt(#2(L.force first))
        val expression=D.delay(fn()=>force(#1(L.force first)))
      in(F.cons(expression,F.defer(fn()=> #1(L.force rest))),#2(L.force rest))end
   |_=>panic"dxDiff_list: unequal lists")
 fun domainDifference big small=
   let val result=differenceAux small big(int 97,F.empty())
       val(expression,(_,substitutions))=L.force result
   in(expression,substitutions)end
