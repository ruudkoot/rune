 fun lookupAssociation equal entries key=D.delay(fn()=>case force entries of F.Nil=>Nothing
   |F.Cons(entry,rest)=>let val(k,v)=force entry
      in if equal key k then Just v else force(lookupAssociation equal rest key)end)

 type analysisSequence=(oneFuncSize F.node F.seq*oneFuncSize F.node F.seq)L.delay
 fun staticExpressions((xs,_,_,_,_,_,_):static)=xs
 fun staticDomains((_,xs,_,_,_,_,_):static)=xs
 fun staticConstructors((_,_,xs,_,_,_,_):static)=xs
 fun staticFreeVariables((_,_,_,xs,_,_,_):static)=xs
 fun staticFlags((_,_,_,_,xs,_,_):static)=xs
 fun staticLimits((_,_,_,_,_,xs,_):static)=xs
 fun staticSizes((_,_,_,_,_,_,xs):static)=xs
 fun hasFlag statics flag=any(equalFlag(cell flag))(staticFlags statics)
 fun zip4Exact f as_ bs cs ds=zipExact(fn triple=>fn d=>
    let val(a,b,c)=force triple in f a b c d end)(zip3Exact triple as_ bs cs)ds
 fun zip5Exact f as_ bs cs ds es=zipExact(fn first=>fn e=>
    let val(a,b,c,d)=force first in f a b c d e end)
      (zip4Exact(fn a=>fn b=>fn c=>fn d=>cell(a,b,c,d))as_ bs cs ds)es
 fun cafDomain domain:domain=D.delay(fn()=>case force domain of Func _=>force domain|_=>Func(F.empty(),domain))
 fun uncafDomain domain:domain=D.delay(fn()=>case force domain of Func(args,target)=>
    if null args then force target else force domain|_=>force domain)
 fun makeFunction arguments target:domain=D.delay(fn()=>if null arguments then force target else Func(arguments,target))
 fun functionArguments domain=F.defer(fn()=>case force domain of Func(args,_)=>args|_=>raise Match)
 fun functionResult domain:domain=D.delay(fn()=>case force domain of Func(_,target)=>force target|_=>raise Match)
 fun sequenceEmpty sequence=let val(used,unused)=L.force sequence in null used end
 fun nextRecursive sequence=let val(used,unused)=L.force sequence in head used end
 fun nextNonRecursive sequence=head(nextRecursive sequence)
 fun sequenceTail sequence=L.delay(fn()=>let val(used,unused)=L.force sequence in(tail used,unused)end)
 fun sequenceGaveUp sequence=let val(used,unused)=L.force sequence in not(null unused)end
 fun isAnalysisResult value=case force value of SAResult _=>true|_=>false
 fun analysisResult value:route=D.delay(fn()=>case force value of SAResult(_,_,r)=>force r|_=>raise Match)
 fun makeSizeInformation sequence names=
   let val(used,unused)=L.force sequence
       val usedT=transpose used
       val unusedT=F.defer(fn()=>if null unused then map(fn _=>F.empty())usedT else transpose unused)
   in zip3Exact(fn name=>fn used=>fn unused=>cell(SASizes(name,used,unused)))names usedT unusedT end
 fun substituteAnalysis rho expression:hexpr=D.delay(fn()=>case force expression of
    HVar v=>if force(head v)= #"_"then HPoint(sureLookup equalName rho"sa(8)"v)else force expression
   |HPoint _=>force expression|HApp(a,b)=>HApp(substituteAnalysis rho a,substituteAnalysis rho b)
   |HMeet xs=>HMeet(map(substituteAnalysis rho)xs)|HLam(vs,e)=>HLam(vs,substituteAnalysis rho e)
   |HTable t=>HTable(mapSecond(substituteAnalysis rho)t)|HVAp(f,args)=>HVAp(substituteAnalysis rho f,map(substituteAnalysis rho)args))
 fun analysisGroups tree=F.defer(fn()=>let val(_,expression)=force tree
   in case force expression of ALet(recursive,defs,body)=>F.cons(pair recursive defs,analysisGroups body)|_=>F.empty()end)
 fun constructorArguments definitions=flatMap(fn definition=>
   let val(_,variables,alternatives)=force definition
       fun find v values=case force values of F.Nil=>raise Match|F.Cons(x,rest)=>
           if equalName v x then int 0 else add(int 1)(find v rest)
       fun oneExpression expr=case force expr of TDefVar v=>cell(ConstrVar(find v variables))|TDefCons _=>cell ConstrRec
   in mapSecond(map oneExpression)alternatives end)definitions
