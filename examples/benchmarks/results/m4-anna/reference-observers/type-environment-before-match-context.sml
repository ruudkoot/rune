 fun lookupAll equal associations key=F.defer(fn()=>case force associations of F.Nil=>F.empty()
   |F.Cons(entry,rest)=>let val(k,value)=force entry
     in if equal k key then F.cons(value,lookupAll equal rest key)else lookupAll equal rest key end)
 fun checkUnifier reply=case L.force reply of Ok phi=>phi
   |Failed message=>panic("tcCheckUnifier: "^string message)
 fun unifyTypeSet phi types:unifyReply=L.delay(fn()=>case force types of F.Nil=>raise Match
   |F.Cons(first,rest)=>case force rest of F.Nil=>Ok phi|F.Cons(second,tail)=>
      if null tail then L.force(unify phi(first,second))
      else let val next=case L.force(unify phi(first,second))of Ok phi=>phi
            |Failed message=>panic("tcDeOkSel: "^string message)
           in L.force(unifyTypeSet next rest)end)
 fun mergeSubstitutions phi=
   let val variables=unique equalTVName(map(fn entry=>let val(v,_)=force entry in v end)phi)
       val groups=map(lookupAll equalTVName phi)variables
       val unifiers=map(fn group=>
         let val reply=unifyTypeSet(F.empty())group in checkUnifier reply end)groups
       fun oldUnified us groups=F.defer(fn()=>case(force us,force groups)of(F.Nil,F.Nil)=>F.empty()
         |(F.Cons(u,ut),F.Cons(group,gt))=>F.cons(substituteType u(head group),oldUnified ut gt)
         |_=>raise Match)
       val newBindings=concat unifiers
       val oldBindings=zip variables(oldUnified unifiers groups)
   in if null newBindings then oldBindings else mergeSubstitutions(F.append oldBindings newBindings)end
 fun typeBar xs ys=filter(fn x=>not(member equalTVName x ys))xs
 fun schemeUnknowns scheme=let val Scheme(variables,expression)=force scheme
   in typeBar(typeVariables expression)variables end
 fun substituteScheme phi scheme=D.delay(fn()=>let val Scheme(variables,expression)=force scheme
       val filtered=filter(fn entry=>let val(n,_)=force entry
         in not(member equalTVName n variables)end)phi
   in Scheme(variables,substituteType filtered expression)end)
 fun charValue associations key=
   let fun find associations=case force associations of F.Nil=>panic("tcCharVal: no such variable: "^string key)
      |F.Cons(entry,rest)=>let val(n,value)=force entry
        in if equalName n key then value else find rest end
   in find associations end
 fun environmentUnknowns gamma=
   let val schemes=map(fn entry=>let val(_,scheme)=force entry in scheme end)gamma
   in concat(map schemeUnknowns schemes)end
 fun substituteEnvironment phi gamma=
   map(fn entry=>let val(n,scheme)=force entry in pair n(substituteScheme phi scheme)end)gamma
 val typeSupplyDoubleLimit=cell(0wx40000000:W.word)
 val typeSupplySuccessorLimit=add typeSupplyDoubleLimit(subtract typeSupplyDoubleLimit(int 1))
 fun typeSupplySuccessor values=F.defer(fn()=>case force values of F.Nil=>singleton(int 1)
   |F.Cons(n,rest)=>if less n typeSupplySuccessorLimit then F.cons(add n(int 1),rest)
       else F.cons(int 0,typeSupplySuccessor rest))
 fun typeSupplyDouble values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(n,rest)=>let
       val next=D.delay(fn()=>force(if less typeSupplyDoubleLimit n then subtract n typeSupplyDoubleLimit else n))
       val tail=F.defer(fn()=>if equalInt next n then typeSupplyDouble rest
         else typeSupplySuccessor(typeSupplyDouble rest))
     in F.cons(multiply(int 2)next,tail)end)
 fun depleteTypeSupply(f,s)=(f,typeSupplySuccessor s)
 fun splitTypeSupply(f,s)=let val doubled=typeSupplyDouble f
   in((doubled,singleton(int 0)),(typeSupplySuccessor doubled,singleton(int 0)))end
 fun typeNameSequence supply=C.defer(fn()=>C.cons(L.delay(fn()=>cell supply),typeNameSequence(depleteTypeSupply supply)))
