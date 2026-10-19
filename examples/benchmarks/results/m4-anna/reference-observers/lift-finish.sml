 type flattenResult=(coreBinding F.seq*core)L.delay
 fun flattenedBindings(result:flattenResult)=F.defer(fn()=>let val(definitions,_)=L.force result in definitions end)
 fun flattenedBody(result:flattenResult):core=D.delay(fn()=>let val(_,body)=L.force result in force body end)
 fun flattenCore(expression:core):flattenResult=L.delay(fn()=>case force expression of
    EVar n=>(F.empty(),cell(EVar n))|ENum n=>(F.empty(),cell(ENum n))
   |EConstr n=>(F.empty(),cell(EConstr n))
   |EAp(a,b)=>let val x=flattenCore a val y=flattenCore b
       in(F.append(flattenedBindings x)(flattenedBindings y),cell(EAp(flattenedBody x,flattenedBody y)))end
   |ELam(args,e)=>let val result=flattenCore e
       in(flattenedBindings result,cell(ELam(args,flattenedBody result)))end
   |ECase(e,alternatives)=>
       let val selector=flattenCore e
           val fixed=map(fn entry=>let val(tag,value)=force entry val(args,body)=force value
             in pair tag(pair args(flattenCore body))end)alternatives
           val alternatives=map(fn entry=>let val(tag,value)=force entry val(args,result)=force value
             in pair tag(pair args(flattenedBody result))end)fixed
           val bindings=flatMap(fn entry=>let val(_,value)=force entry val(_,result)=force value
             in flattenedBindings result end)fixed
       in(F.append(flattenedBindings selector)bindings,cell(ECase(flattenedBody selector,alternatives)))end
   |ELet(_,definitions,body)=>
       let val rhs=flattenCore body
           val fixed=map(fn entry=>let val(n,e)=force entry in pair n(flattenCore e)end)definitions
           val here=map(fn entry=>let val(n,result)=force entry in pair n(flattenedBody result)end)fixed
           val inside=flatMap(fn entry=>let val(_,result)=force entry in flattenedBindings result end)fixed
       in(F.append(F.append here inside)(flattenedBindings rhs),flattenedBody rhs)end)
 fun rootName n=takeWhile(fn c=>force c<> #")")n
 fun contentious names=
   let fun collisions names=F.defer(fn()=>case force names of F.Nil=>F.empty()
        |F.Cons(x,rest)=>(case force rest of F.Nil=>F.empty()|F.Cons(y,ys)=>
          if equalName(rootName x)(rootName y)then F.cons(x,F.cons(y,collisions rest))else collisions rest))
   in unique equalName(collisions(insertionSort compareName names))end
 fun prettyScName names n=if firstChar n= #"_"andalso not(member equalName n names)then rootName n else n
 fun prettyVariableName names n=if firstChar n<> #"_"andalso not(member equalName n names)then rootName n else n
 fun prettyLifted definitions freeParameters=
   let val names=map(fn entry=>let val(n,_)=force entry in n end)definitions
       val scTable=contentious names
       val scDefinitions=map(fn entry=>let val(n,e)=force entry
         in pair(prettyScName scTable n)(mapCore(prettyScName scTable)e)end)definitions
       val freeParameters=mapFirst(prettyScName scTable)freeParameters
       val lambdaTables=map(fn entry=>let val(_,e)=force entry
         in case force e of ELam(args,_)=>contentious args|_=>F.empty()end)scDefinitions
       fun fixParameters entry table=let val(n,ps)=force entry
         in pair n(map(prettyVariableName table)ps)end
       fun fixDefinition entry table=let val(n,e)=force entry
         in pair n(mapCore(prettyVariableName table)e)end
   in(zipExact fixDefinition scDefinitions lambdaTables,
      zipExact fixParameters freeParameters lambdaTables)end
 fun lambdaLift builtins expression pretty=L.delay(fn()=>
   let val builtinFunctions=filter(fn n=>firstChar n= #"_")builtins
       val initialEnv=map(fn n=>pair(tail n)n)builtinFunctions
       val depended=depend expression
       val merged=mergeLambdas depended
       val named=nameLambdas merged
       val unique=uniqueBody(uniqueNames(int 0)initialEnv named)
       val annotation=liftFreeVariables unique
       val equations=map(zapBuiltins builtinFunctions)(liftEquations annotation)
       val solution=solveLiftEquations equations
       val result=flattenCore(addLiftParameters solution annotation)
       val definitions=flattenedBindings result val body=flattenedBody result
       val parameters=mapSecond setValues solution
       val polished=if pretty then prettyLifted definitions parameters else(definitions,parameters)
       val(definitions,parameters)=polished
       val reconstituted=cell(ELet(cell true,definitions,body))
   in(depend reconstituted,parameters)end)
