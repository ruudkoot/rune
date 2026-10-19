 fun concat lists=flatMap(fn values=>values)lists
 fun member equal value values=any(fn other=>equal value other)values
 fun unique equal values=let
     fun scan values seen=F.defer(fn()=>case force values of F.Nil=>F.empty()
       |F.Cons(x,rest)=>if member equal x seen then scan rest seen
         else F.cons(x,scan rest(F.cons(x,seen))))
   in scan values(F.empty())end
 fun freeTypeVariables definition=
   let val(_,parameters,alternatives)=force definition
       fun variables expression=F.defer(fn()=>case force expression of TDefVar n=>singleton n
         |TDefCons(n,args)=>F.cons(n,flatMap variables args))
       val all=flatMap(fn alt=>let val(_,types)=force alt in flatMap variables types end)alternatives
       val excluded=F.append parameters(F.fromList(List.map
           (fn s=>case force(name s)of F.Nil=>F.Nil|node=>node)["int","bool","char"]))
   in setValues(setSubtract compareName(setFromList compareName all)(setFromList compareName excluded))end
 fun typeEdges definitions=
   let val froms=map(fn definition=>let val(name,_,_)=force definition in name end)definitions
       val tos=map freeTypeVariables definitions
   in flatMap(fn edge=>let val(from,targets)=force edge
       in map(fn target=>pair from target)targets end)(zip froms tos)end
 fun typeDependency definitions=
   let val edges=typeEdges definitions
       fun incoming vertex=map(fn edge=>let val(from,_)=force edge in from end)
         (filter(fn edge=>let val(_,target)=force edge in equalName vertex target end)edges)
       fun outgoing vertex=map(fn edge=>let val(_,target)=force edge in target end)
         (filter(fn edge=>let val(from,_)=force edge in equalName vertex from end)edges)
       val roots=unique equalName(map(fn definition=>let val(name,_,_)=force definition in name end)definitions)
       fun group values=D.delay(fn()=>
         let val first=head values
         in if null(tail values)then
             let fun find definitions=case force definitions of F.Nil=>raise Match|F.Cons(definition,rest)=>
                   let val(name,_,_)=force definition in if equalName first name then definition else find rest end
             in(cell(member equalName first(freeTypeVariables(find definitions))),values)end
            else(cell true,values)end)
   in map(fn component=>group(setValues component))(stronglyConnected compareName incoming outgoing roots)end
 fun isRecursiveType groups name=case force groups of F.Nil=>raise Match|F.Cons(group,rest)=>
   let val(recursive,names)=force group
   in if member equalName name names then force recursive else isRecursiveType rest name end
