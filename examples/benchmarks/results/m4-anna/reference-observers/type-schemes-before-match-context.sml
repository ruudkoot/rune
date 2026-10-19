 fun zipTypeNames names supply=F.defer(fn()=>case force names of F.Nil=>F.empty()
   |F.Cons(n,rest)=>case L.force supply of C.Nil=>F.empty()|C.Cons(v,tail)=>
      F.cons(pair n(L.force v),zipTypeNames rest tail))
 fun newTypeInstance supply scheme=
   let val Scheme(variables,expression)=force scheme
       val association=zipTypeNames variables(typeNameSequence supply)
       val phi=mapSecond(fn variable=>cell(TVar variable))association
   in substituteType phi expression end
 fun generalizedScheme unknowns supply expression=D.delay(fn()=>
   let val variables=typeBar(unique equalTVName(typeVariables expression))unknowns
       val association=zipTypeNames variables(typeNameSequence supply)
       val mappedVariables=map(fn entry=>let val(_,v)=force entry in v end)association
       val phi=mapSecond(fn variable=>cell(TVar variable))association
   in Scheme(mappedVariables,substituteType phi expression)end)
 fun addTypeDeclarations gamma supply names types=
   let val unknowns=environmentUnknowns gamma
       val schemes=map(generalizedScheme unknowns supply)types
   in F.append(zip names schemes)gamma end
 fun newBoundVariable name variable=pair name(cell(Scheme(F.empty(),cell(TVar variable))))
 fun newBoundVariables names supply=
   map(fn entry=>let val(n,v)=force entry in newBoundVariable n v end)(zipTypeNames names(typeNameSequence supply))
 fun oldBoundVariable entry=
   let val(_,scheme)=force entry val Scheme(variables,expression)=force scheme
   in if null variables then expression else raise Match end
 fun typeDefinitionSubstitution names expression:texpr=D.delay(fn()=>case force expression of
    TDefCons(n,args)=>TCons(n,map(typeDefinitionSubstitution names)args)
   |TDefVar n=>let fun find entries=case force entries of F.Nil=>TCons(n,F.empty())
         |F.Cons(entry,rest)=>let val(k,v)=force entry
            in if equalName k n then TVar v else find rest end
     in find names end)
 fun newTypeVariables definition supply=
   let val(_,variables,_)=force definition
   in zipTypeNames variables(typeNameSequence supply)end
 fun constructorTypeSchemes supply definition=
   let val(n,variables,alternatives)=force definition
       val newVariables=newTypeVariables definition supply
       val variablesInType=map(fn entry=>let val(_,v)=force entry in v end)newVariables
       val constructorSignature=cell(TCons(n,map(fn v=>cell(TVar v))variablesInType))
       val translated=mapSecond(fn args=>map(typeDefinitionSubstitution newVariables)args)alternatives
       val curried=mapSecond(fn args=>foldRight(fn arg=>fn result=>cell(TArr(arg,result)))constructorSignature args)translated
       fun scheme expression=cell(Scheme(unique equalTVName(typeVariables expression),expression))
       fun deplete n supply=if equalInt n(int 0)then supply
         else deplete(subtract n(int 1))(depleteTypeSupply supply)
       val next=deplete(add(length variablesInType)(int 2))supply
   in(next,mapSecond scheme curried)end
