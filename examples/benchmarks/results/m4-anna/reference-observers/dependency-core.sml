 fun dependencyExpression(annotation:freeAnnotation):core=D.delay(fn()=>
   let val(_,node)=force annotation
   in case force node of ANum n=>ENum n|AVar n=>EVar n|AConstr n=>EConstr n
     |AAp(a,b)=>EAp(dependencyExpression a,dependencyExpression b)
     |ALam(args,body)=>ELam(args,dependencyExpression body)
     |ACase(e,alternatives)=>ECase(dependencyExpression e,map(fn alternative=>
        let val(tag,value)=force alternative val(args,e)=force value
        in pair tag(pair args(dependencyExpression e))end)alternatives)
     |ALet(recursive,definitions,body)=>
        let val binders=map(fn entry=>let val(n,_)=force entry in n end)definitions
            val binderSet=D.delay(fn()=>force(if force recursive then setFromList compareName binders else setEmpty()))
            val edges=flatMap(fn entry=>let val(n,annotation)=force entry
               val free=annotationSet annotation
             in map(fn target=>pair n target)(setValues(setIntersection compareName free binderSet))end)definitions
            fun incoming vertex=map(fn edge=>let val(n,_)=force edge in n end)
                (filter(fn edge=>let val(_,target)=force edge in equalName vertex target end)edges)
            fun outgoing vertex=map(fn edge=>let val(_,target)=force edge in target end)
                (filter(fn edge=>let val(n,_)=force edge in equalName vertex n end)edges)
            val components=map setValues(stronglyConnected compareName incoming outgoing binders)
            val groups=map(fn names=>map(fn n=>pair n(sureLookup equalName definitions
                ("depends"^String.str(Char.chr 96)^"defnGroups")n))names)components
            fun elet group e=D.delay(fn()=>
              let fun nonRecursive definitions=case force definitions of F.Nil=>false
                    |F.Cons(definition,rest)=>if null rest then
                      let val(n,a)=force definition in not(setMember compareName n(annotationSet a))end else false
                  val isRecursive=force recursive andalso not(nonRecursive group)
                  val definitions=map(fn entry=>let val(n,a)=force entry in pair n(dependencyExpression a)end)group
              in ELet(cell isRecursive,definitions,e)end)
        in force(foldRight elet(dependencyExpression body)groups)end
   end)
 fun depend expression=dependencyExpression(freeVariables expression)
