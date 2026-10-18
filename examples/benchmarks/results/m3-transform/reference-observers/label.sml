 fun pairValue pair=D.delay(fn()=>let val(value,_)=L.force pair in D.force value end)
 fun pairCounter pair=D.delay(fn()=>let val(_,counter)=L.force pair in D.force counter end)
 fun increment q=D.delay(fn()=>D.force q+2)
 fun labelList f values reversed q=L.delay(fn()=>case D.force values of
     F.Nil=>(reverse reversed,q)
    |F.Cons(value,rest)=>let val result=f(D.force value)q
       in L.force(labelList f rest(cons(pairValue result)reversed)(pairCounter result))end)
 fun labelDef definition q=L.delay(fn()=>case D.force definition of
     Caf(names,e)=>let val result=labelExpr e q
       in(caf names(pairValue result),pairCounter result)end
    |Def(name,args,e,w)=>let val result=labelExpr e q
         val whereResult=labelWhere w(pairCounter result)
       in(def name args(pairValue result)(pairValue whereResult),pairCounter whereResult)end)
 and labelWhere wherePart q=L.delay(fn()=>case D.force wherePart of
     NoWhere=>(noWhere(),q)
    |Where program=>let val result=labelDefs program q in(whereExpr(pairValue result),pairCounter result)end)
 and labelExpr expr q=L.delay(fn()=>case D.force expr of
     Tail(_,e)=>let val result=labelExpr e(increment q)
       in(tailExpr q(pairValue result),pairCounter result)end
    |Cons(_,s,e)=>let val stream=labelExpr e(increment q)
         val state=labelExpr s(pairCounter stream)
       in(consExpr q(pairValue state)(pairValue stream),pairCounter state)end
    |Map(_,name,args)=>let val result=labelExprs args(increment q)
       in(mapExpr q name(pairValue result),pairCounter result)end
    |Maps(_,f,g,s,args)=>let val result=labelExprs args(increment q)
         val state=labelExpr s(pairCounter result)
       in(mapsExpr q f g(pairValue state)(pairValue result),pairCounter state)end
    |Ap(name,args)=>let val result=labelExprs args q in(ap name(pairValue result),pairCounter result)end
    |Tuple args=>let val result=labelExprs args q in(tuple(pairValue result),pairCounter result)end
    |_=>(expr,q))
 and labelDefs program q=labelList labelDef program(empty())q
 and labelExprs exprs q=labelList labelExpr exprs(empty())q

 fun label program=pairValue(labelDefs program(fromInt 1))
