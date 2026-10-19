 type freeAnnotation=(nameNode,nameNode setNode)ann
 fun annotationSet value=let val(free,_)=force value in free end
 fun freeVariables(expression:core):freeAnnotation=D.delay(fn()=>case force expression of
    ENum n=>(setEmpty(),cell(ANum n))
   |EVar n=>(setSingleton n,cell(AVar n))
   |EConstr n=>(setEmpty(),cell(AConstr n))
   |EAp(a,b)=>let val x=freeVariables a val y=freeVariables b
       in(setUnion compareName(annotationSet x)(annotationSet y),cell(AAp(x,y)))end
   |ELam(args,body)=>let val value=freeVariables body
       in(setSubtract compareName(annotationSet value)(setFromList compareName args),
          cell(ALam(args,value)))end
   |ECase(e,alternatives)=>
       let val value=freeVariables e
           val alternatives=map(fn alternative=>let val(tag,body)=force alternative
               val(args,e)=force body
             in pair tag(pair args(freeVariables e))end)alternatives
           val free=setUnionList compareName(map(fn alternative=>let val(_,body)=force alternative
                val(args,e)=force body
              in setSubtract compareName(annotationSet e)(setFromList compareName args)end)alternatives)
       in(setUnion compareName(annotationSet value)free,cell(ACase(value,alternatives)))end
   |ELet(recursive,bindings,body)=>
       let val binders=map(fn p=>let val(name,_)=force p in name end)bindings
           val binderSet=setFromList compareName binders
           val values=map(fn p=>let val(_,e)=force p in freeVariables e end)bindings
           val annotated=zip binders values
           val valuesFree=setUnionList compareName(map annotationSet values)
           val definitionsFree=D.delay(fn()=>force(if force recursive
             then setSubtract compareName valuesFree binderSet else valuesFree))
           val body=freeVariables body
           val bodyFree=setSubtract compareName(annotationSet body)binderSet
       in(setUnion compareName definitionsFree bodyFree,cell(ALet(recursive,annotated,body)))end)
 fun depthFirst compare relation initial vertices=
   foldLeft(fn state=>fn vertex=>D.delay(fn()=>
     let val(visited,sequence)=force state
     in if setMember compare vertex visited then(visited,sequence)else
       let val next=L.delay(fn()=>force(depthFirst compare relation
               (pair(setUnion compare visited(setSingleton vertex))sequence)(relation vertex)))
           val visited=D.delay(fn()=>force(#1(L.force next)))
           val sequence=F.defer(fn()=> #2(L.force next))
       in(visited,F.cons(vertex,sequence))end end))initial vertices
 fun spanningSearch compare relation initial vertices=
   foldLeft(fn state=>fn vertex=>D.delay(fn()=>
     let val(visited,components)=force state
     in if setMember compare vertex visited then(visited,components)else
       let val next=L.delay(fn()=>force(depthFirst compare relation
               (pair(setUnion compare visited(setSingleton vertex))(F.empty()))(relation vertex)))
           val visited=D.delay(fn()=>force(#1(L.force next)))
           val sequence=F.defer(fn()=> #2(L.force next))
       in(visited,F.cons(setFromList compare(F.cons(vertex,sequence)),components))end end))initial vertices
 fun stronglyConnected compare incoming outgoing roots=
   let val first=depthFirst compare outgoing(pair(setEmpty())(F.empty()))roots
       val ordered=F.defer(fn()=>let val(_,vertices)=force first in vertices end)
       val second=spanningSearch compare incoming(pair(setEmpty())(F.empty()))ordered
   in F.defer(fn()=>let val(_,components)=force second in components end)end
