 fun liftFreeVariables(expression:core):freeAnnotation=D.delay(fn()=>case force expression of
    ENum n=>(setEmpty(),cell(ANum n))|EVar n=>(setSingleton n,cell(AVar n))
   |EConstr n=>(setEmpty(),cell(AConstr n))
   |EAp(a,b)=>let val x=liftFreeVariables a val y=liftFreeVariables b
       in(setUnion compareName(annotationSet x)(annotationSet y),cell(AAp(x,y)))end
   |ELam(args,e)=>let val body=liftFreeVariables e
       in(setSubtract compareName(annotationSet body)(setFromList compareName args),cell(ALam(args,body)))end
   |ECase(e,alternatives)=>let val e=liftFreeVariables e
       val alternatives=map(fn entry=>let val(tag,value)=force entry val(args,body)=force value
         in pair tag(pair args(liftFreeVariables body))end)alternatives
       val free=setUnionList compareName(map(fn entry=>let val(_,value)=force entry val(args,body)=force value
         in setSubtract compareName(annotationSet body)(setFromList compareName args)end)alternatives)
       in(setUnion compareName(annotationSet e)free,cell(ACase(e,alternatives)))end
   |ELet(recursive,definitions,e)=>
       let val(binders,values)=unzip definitions val bound=setFromList compareName binders
           val values=map liftFreeVariables values
           val definitions=zip binders values
           val freeValues=setUnionList compareName(map annotationSet values)
           val definitionFree=D.delay(fn()=>force(if force recursive then setSubtract compareName freeValues bound else freeValues))
           val body=liftFreeVariables e
           val bodyFree=setSubtract compareName(annotationSet body)bound
       in(setUnion compareName definitionFree bodyFree,cell(ALet(recursive,definitions,body)))end)
 fun splitFreeSet collection=
   let fun split result value=let val(fs,vs)=force result
         in if firstChar value= #"_"then pair(F.cons(value,fs))vs else pair fs(F.cons(value,vs))end
       val result=foldLeft split(pair(F.empty())(F.empty()))(setValues collection)
       val functions=F.defer(fn()=>let val(fs,_)=force result in fs end)
       val variables=F.defer(fn()=>let val(_,vs)=force result in vs end)
   in(setFromList compareName functions,setFromList compareName variables)end
 fun liftEquations(annotation:freeAnnotation)=F.defer(fn()=>
   let val(_,node)=force annotation
   in case force node of AVar _=>F.empty()|ANum _=>F.empty()|AConstr _=>F.empty()
    |AAp(a,b)=>F.append(liftEquations a)(liftEquations b)
    |ALam(_,body)=>liftEquations body
    |ACase(e,alternatives)=>F.append(liftEquations e)(flatMap(fn entry=>
        let val(_,value)=force entry val(_,body)=force value in liftEquations body end)alternatives)
    |ALet(_,definitions,body)=>
       let val here=map(fn entry=>D.delay(fn()=>let val(n,annotation)=force entry
             val(functions,variables)=splitFreeSet(annotationSet annotation)
           in EqnNVC(n,variables,functions)end))definitions
           val inside=flatMap(fn entry=>let val(_,body)=force entry in liftEquations body end)definitions
       in F.append here(F.append inside(liftEquations body))end end)
 fun zapBuiltins builtins equation=D.delay(fn()=>
   let val EqnNVC(n,v,c)=force equation
       val names=filter(fn name=>not(member equalName name builtins))(setValues c)
   in EqnNVC(n,v,setFromList compareName names)end)
 fun equalNameSets a b=equalLists equalName(setValues a)(setValues b)
 fun equalFreeEnvironments xs ys=equalLists(fn a=>fn b=>
   let val(n,x)=force a val(m,y)=force b in equalName n m andalso equalNameSets x y end)xs ys
 fun solveLiftEquations equations=
   let val initial=map(fn equation=>let val EqnNVC(n,_,_)=force equation in pair n(setEmpty())end)equations
       fun substitute env equation=
         let val EqnNVC(n,v,c)=force equation
             val names=F.append(setValues v)(setValues c)
             val substituted=map(fn variable=>lookupDefault equalName env variable(setSingleton variable))names
             val all=setUnionList compareName substituted
             val(_,variables)=splitFreeSet all
         in pair n variables end
       fun loop env=let val next=map(substitute env)equations
         in if equalFreeEnvironments next env then next else loop next end
   in loop initial end
 fun addLiftParameters env(annotation:freeAnnotation):core=D.delay(fn()=>
   let val(_,node)=force annotation
   in case force node of ANum n=>ENum n|AConstr n=>EConstr n
    |AVar n=>let fun find env=case force env of F.Nil=>NONE|F.Cons(entry,rest)=>
          let val(k,v)=force entry in if equalName k n then SOME v else find rest end
        in case find env of NONE=>EVar n|SOME values=>
            force(foldLeft(fn f=>fn a=>cell(EAp(f,a)))(cell(EVar n))
                (map(fn n=>cell(EVar n))(setValues values)))end
    |AAp(a,b)=>EAp(addLiftParameters env a,addLiftParameters env b)
    |ALam(args,body)=>ELam(args,addLiftParameters env body)
    |ACase(e,alternatives)=>ECase(addLiftParameters env e,map(fn entry=>
        let val(tag,value)=force entry val(args,body)=force value
        in pair tag(pair args(addLiftParameters env body))end)alternatives)
    |ALet(recursive,definitions,body)=>
        let val definitions=map(fn entry=>let val(n,rhs)=force entry val(df,node)=force rhs
              val parameters=setValues(sureLookup equalName env
                   (case force node of ALam _=>"llAddParams1"|_=>"llAddParams2")n)
              val lifted=D.delay(fn()=>case force node of ALam(args,e)=>
                   ELam(F.append parameters args,addLiftParameters env e)
                |_=>ELam(parameters,addLiftParameters env(pair df node)))
            in pair n lifted end)definitions
        in ELet(recursive,definitions,addLiftParameters env body)end end)
