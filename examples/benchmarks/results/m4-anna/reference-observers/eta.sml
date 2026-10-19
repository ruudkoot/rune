 fun curryType result types:texpr=D.delay(fn()=>case force types of F.Nil=>force result
   |F.Cons(arg,rest)=>TArr(arg,curryType result rest))
 fun uncurryType expression=L.delay(fn()=>case force expression of
    TVar variable=>(F.empty(),cell(TVar variable))
   |TCons(n,args)=>(F.empty(),cell(TCons(n,args)))
   |TArr(arg,result)=>let val rest=uncurryType result
       val arguments=F.defer(fn()=>let val(args,_)=L.force rest in args end)
       val final=D.delay(fn()=>let val(_,result)=L.force rest in force result end)
     in(F.cons(arg,arguments),final)end)
 fun etaNewArguments count names=
   let val leading=filter(fn name=>not(null name))(map(takeWhile(fn c=>force c= #"v"))names)
       val root=F.append(last(insertionSort compareName(F.cons(F.empty(),leading))))(name"v")
   in map(fn n=>F.append root(name(signed n)))(intsFromTo(int 1)count)end
 fun etaMain entry argumentTypes resultType=
   let val(n,tree)=force entry val(tau,node)=force tree
       val(args,body)=case force node of ALam(args,body)=>(args,body)|_=>raise Match
       val actual=length args val required=length argumentTypes
       val newArgs=etaNewArguments(subtract required actual)args
       val newTypes=zipExact pair newArgs(drop actual argumentTypes)
       val appArgs=map(fn n=>drop n argumentTypes)(intsFromTo actual(subtract required(int 1)))
       val appTypes=map(curryType resultType)appArgs
       val specs=zipExact pair newTypes appTypes
       fun chain specs tree=case force specs of F.Nil=>tree|F.Cons(spec,rest)=>
         let val(vtype,aptype)=force spec val(v,t)=force vtype
         in chain rest(pair aptype(cell(AAp(tree,pair t(cell(AVar v))))))end
       val newBody=chain specs body
   in pair n(pair tau(cell(ALam(F.append args newArgs,newBody))))end
 fun etaAbstract(tree:typedAnnotation):typedAnnotation=D.delay(fn()=>
   let val(tau,node)=force tree
   in case force node of AVar _=>force tree|ANum _=>force tree|AConstr _=>force tree
      |AAp(a,b)=>(tau,cell(AAp(etaAbstract a,etaAbstract b)))
      |ALam(args,e)=>(tau,cell(ALam(args,etaAbstract e)))
      |ACase(e,alternatives)=>(tau,cell(ACase(etaAbstract e,map(fn entry=>
          let val(n,value)=force entry val(args,e)=force value
          in pair n(pair args(etaAbstract e))end)alternatives)))
      |ALet(recursive,definitions,body)=>
         let val info=map(fn entry=>let val(_,tree)=force entry val(t,_)=force tree
               in cell(uncurryType t)end)definitions
             fun merge tree=D.delay(fn()=>let val(t,node)=force tree
               in case force node of ALam(args,body)=>let val(_,inner)=force body
                    in case force inner of ALam(more,e)=>force(merge(pair t(cell(ALam(F.append args more,e)))))
                      |_=>force tree end|_=>force tree end)
             val merged=mapSecond merge definitions
             fun fix entry info=
               let val(_,tree)=force entry val(t,node)=force tree val(args,result)=L.force(force info)
               in case force node of ALam(parameters,_)=>
                   if equalInt(length parameters)(length args)then entry
                   else if less(length args)(length parameters)then panic"eaEtaAbstract"
                   else etaMain entry args result
                  |_=>if null args then entry else
                     let val(n,_)=force entry
                     in etaMain(pair n(pair t(cell(ALam(F.empty(),tree)))))args result end
               end
             val fixed=zipExact fix merged info
         in(tau,cell(ALet(recursive,fixed,etaAbstract body)))end end)
