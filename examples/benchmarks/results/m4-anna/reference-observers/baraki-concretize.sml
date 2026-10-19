
 type embeddingSubstitution=(name*(domain*route*route)D.t)F.seq
 fun embeddingDomain rho expression:domain=D.delay(fn()=>case force expression of
    DXTwo=>Two|DXLift1 xs=>Lift1(map(embeddingDomain rho)xs)
   |DXLift2 xs=>Lift2(map(embeddingDomain rho)xs)
   |DXFunc(xs,x)=>Func(map(embeddingDomain rho)xs,embeddingDomain rho x)
   |DXVar n=>let val(d,_,_)=force(sureLookup equalName rho"bcEApp_d"n)in force d end)
 fun applyEmbedding rho expression point:route=D.delay(fn()=>case(force expression,force point)of
    (DXTwo,Zero)=>Zero|(DXTwo,One)=>One|(DXLift1 _,Stop1)=>Stop1
   |(DXLift1 xs,Up1 rs)=>Up1(zipExact(applyEmbedding rho)xs rs)
   |(DXLift2 _,Stop2)=>Stop2|(DXLift2 _,Up2)=>Up2
   |(DXLift2 xs,UpUp2 rs)=>UpUp2(zipExact(applyEmbedding rho)xs rs)
   |(DXVar n,Zero)=>let val(_,r,_)=force(sureLookup equalName rho"bcEApp(1)"n)in force r end
   |(DXVar n,One)=>let val(_,_,t)=force(sureLookup equalName rho"bcEApp(2)"n)in force t end
   |(DXFunc(args,result),Rep rep)=>force(composeEmbeddingFunctionClosure rho result(defaultDomain expression)rep args)
   |_=>raise Match)
 and composeEmbeddingFunction rho target domain rep:representation=D.delay(fn()=>
   case(force target,force domain,force rep)of
      (DXTwo,Func(_,result),RepTwo _)=>(case force result of Two=>force rep|_=>raise Match)
     |(DXLift1 targets,Func(args,result),Rep1(low,highs))=>(case force result of Lift1 ds=>
         Rep1(low,zip3Exact(composeEmbeddingFunction rho)targets(map(uncurryDomain args)ds)highs)|_=>raise Match)
     |(DXLift2 targets,Func(args,result),Rep2(low,middle,highs))=>(case force result of Lift2 ds=>
         Rep2(low,middle,zip3Exact(composeEmbeddingFunction rho)targets(map(uncurryDomain args)ds)highs)|_=>raise Match)
     |(DXVar n,Func(args,result),RepTwo f)=>
       let val _=case force result of Two=>()|_=>raise Match
           val top=topFrontier args
           val topRep=cell(RepTwo top)
           fun base domain:representation=D.delay(fn()=>case force domain of
                Two=>force rep|Lift1 ds=>Rep1(f,map base ds)|Lift2 ds=>Rep2(f,f,map base ds)|_=>raise Match)
           fun value domain point:representation=D.delay(fn()=>case(force domain,force point)of
                (Two,Zero)=>force rep|(Two,One)=>force topRep
               |(Lift1 ds,Stop1)=>Rep1(f,map base ds)
               |(Lift1 ds,Up1 rs)=>Rep1(top,zipExact value ds rs)
               |(Lift2 ds,Stop2)=>Rep2(f,f,map base ds)
               |(Lift2 ds,Up2)=>Rep2(top,f,map base ds)
               |(Lift2 ds,UpUp2 rs)=>Rep2(top,top,zipExact value ds rs)|_=>raise Match)
           val(d,r,_)=force(sureLookup equalName rho"bcEdotF"n)
       in force(value d r)end
     |_=>raise Match)
 and mapBarakiZeros function arguments rep:representation=D.delay(fn()=>case force rep of
    RepTwo f=>RepTwo(mapBarakiZeroFrontier function arguments f)
   |Rep1(f,highs)=>Rep1(mapBarakiZeroFrontier function arguments f,map(mapBarakiZeros function arguments)highs)
   |Rep2(f,m,highs)=>Rep2(mapBarakiZeroFrontier function arguments f,mapBarakiZeroFrontier function arguments m,
        map(mapBarakiZeros function arguments)highs))
 and mapBarakiZeroFrontier function arguments frontier:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force frontier in Min1Max0(arity,F.empty(),map function zeros)end)
 and composeEmbeddingFunctionClosure rho target domain rep closures:route=D.delay(fn()=>
   let val(_,result)=case force domain of Func(args,target)=>(args,target)|_=>raise Match
       val newArgs=map(embeddingDomain rho)closures
       fun apply value=let val MkFrel routes=force value
         in cell(MkFrel(zipExact(applyEmbedding rho)closures routes))end
       val functionClosure=mapBarakiZeros apply newArgs rep
       val finalDomain=cell(Func(newArgs,result))
   in Rep(composeEmbeddingFunction rho target finalDomain functionClosure)end)
 fun cleanDomainExpression expression:dexpr=D.delay(fn()=>case force expression of
    DXTwo=>DXTwo|DXVar _=>force expression
   |DXLift1 xs=>if null xs then DXTwo else DXLift1(map cleanDomainExpression xs)
   |DXLift2 xs=>if null xs then DXLift1(singleton(cell DXTwo))else DXLift2(map cleanDomainExpression xs)
   |DXFunc(args,result)=>DXFunc(map cleanDomainExpression args,cleanDomainExpression result))
 fun makePolymorphicInstance useBaraki threshold mode dirty rho point:route=D.delay(fn()=>
   case(force dirty,force point)of(DXFunc _,Rep rep)=>
     let val simplest=cleanDomainExpression dirty
         val(args,target)=case force simplest of DXFunc(args,result)=>(args,result)|_=>raise Match
         val domains=map(fn entry=> #2(force entry))rho
         val base=all(fn d=>case force d of Two=>true|_=>false)domains
         val applicable=all(fn d=>not(containsFunctions d))domains andalso not(expressionContainsFunctions target)
             andalso all(fn d=>not(expressionContainsSubsidiaryFunctions d))args
         val optimize=all(fn d=>not(expressionContainsFunctions d))args
         fun baraki()=
           let
         val limit=if less threshold(int 1)then int 1 else threshold
         (* The finite strict variant must not construct the unused tail
            of the Cartesian product beyond the original take limit. *)
         fun controlFlatMap function values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
            |C.Cons(x,rest)=>C.append(function x)(controlFlatMap function rest))
         fun controlProduct xss=C.defer(fn()=>case force xss of F.Nil=>C.cons(L.delay(fn()=>F.empty()),C.empty())
           |F.Cons(xs,rest)=>controlFlatMap(fn suffix=>
               let fun loop values=C.defer(fn()=>case force values of F.Nil=>C.empty()
                    |F.Cons(x,xt)=>C.cons(L.delay(fn()=>F.cons(x,L.force suffix)),loop xt))
               in loop xs end)(controlProduct rest))
         val indices=map(fn d=>if optimize then meetIrreducibleRoutes d else allRoutesMinusTop d)domains
         val choices=fromControl(C.take(Int.max(1,small limit))(controlProduct indices))
         val tops=map topRoute domains
         val names=map(fn entry=> #1(force entry))rho
         val dsAndTops=zipExact pair domains tops
         fun substitution routes=zip3Exact(fn n=>fn info=>fn r=>
           let val(d,t)=force info in pair n(triple d r t)end)names dsAndTops routes
         val substitutions=map substitution choices
         val simpleDomain=defaultDomain simplest
         val compositions=map(fn rho=>composeEmbeddingFunctionClosure rho target simpleDomain rep args)substitutions
         val meet=foldLeft barakiMeet(head compositions)(tail compositions)

           in normalizeBaraki(applyDomainSubstitution rho simplest)meet end
     in if base then force point
        else if not useBaraki orelse not applicable then force(makeAbstractInstance mode simplest rho point)
        else force(baraki())end
    |_=>force(makeAbstractInstance mode dirty rho point))
