 fun typedTreeEnvironment(tree:typedAnnotation)=
   let fun nodeEntries node=F.defer(fn()=>case force node of
          AVar _=>F.empty()|ANum _=>F.empty()|AConstr _=>F.empty()
         |AAp(a,b)=>F.append(entries a)(entries b)
         |ALam(_,body)=>entries body
         |ACase(e,alternatives)=>F.append(entries e)(concat(map(fn entry=>
              let val(_,body)=force entry val(_,e)=force body in entries e end)alternatives))
         |ALet(_,definitions,body)=>F.append(concat(map definitionEntries definitions))(entries body))
       and entries tree=let val(_,node)=force tree in nodeEntries node end
       and definitionEntries definition=let val(n,tree)=force definition val(t,node)=force tree
         in F.cons(pair n t,nodeEntries node)end
   in entries tree end
 fun prettyTypeBinding entry=F.defer(fn()=>
   let val(n,t)=force entry val label=F.append n(name" :: ")
       val padded=F.append label(copy(subtract(int 25)(length label))(cell #" "))
   in F.append(name"\n   ")(F.append padded(showType t))end)
 type checkedReply=(typedAnnotation*fullTypeEnv,nameNode)replyNode L.delay
 val builtinTypeDefinitions:typeDef F.seq=
   singleton(triple(name"bool")(F.empty())(F.cons(pair(name"True")(F.empty()),singleton(pair(name"False")(F.empty())))))
 fun checkTypes baseTypes supply program=
   let val(definitions,expression)=force program
       val definitions=F.append definitions builtinTypeDefinitions
       fun constructors supply definition=
         let val(next,schemes)=constructorTypeSchemes(force supply)definition
         in(cell next,schemes)end
       val accumulated=mapAccumulate constructors(cell supply)definitions
       val finalSupply=let val(final,_)=L.force accumulated in force final end
       val constructorGroups=F.defer(fn()=>let val(_,groups)=L.force accumulated in groups end)
       val constructorTypes=concat constructorGroups
       val result=infer definitions(F.append baseTypes constructorTypes)finalSupply expression
       val checked:checkedReply=L.delay(fn()=>case L.force result of Failed _=>Failed(name"No type")
         |Ok value=>let val(phi,t,tree)=force value
             val root=mapAnnotation(substituteType phi)tree
             val fromTree=typedTreeEnvironment root
             val constructorEnvironment=map(fn entry=>let val(n,scheme)=force entry
                val Scheme(_,t)=force scheme in pair n t end)constructorTypes
             val environment=F.append fromTree constructorEnvironment
           in Ok(pair root environment)end)
       val words=F.defer(fn()=>case L.force checked of Failed _=>F.empty()
         |Ok value=>let val(_,environment)=force value
           in concat(map prettyTypeBinding environment)end)
   in(words,checked)end
