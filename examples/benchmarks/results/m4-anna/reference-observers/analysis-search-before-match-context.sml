
 fun finalExpansion statics finalDomains currentDomains safe=
   let val(_,mono,_,_,_)=staticLimits statics
       val differences=zipExact(fn final=>fn current=>
           let val(expression,substitution)=domainDifference final current in pair expression substitution end)finalDomains currentDomains
   in zipExact(fn info=>fn point=>let val(expression,substitution)=force info
       in makePolymorphicInstance false mono Safe expression substitution point end)differences safe end
 fun nonRecursiveSearch statics name sequence oldArgs target finalArgs oldSafe oldLive tree=F.defer(fn()=>
   let val finished=sequenceEmpty(sequenceTail sequence)
       val(size,args)=force(nextNonRecursive sequence)
       val domain=makeFunction args target
       val finalDomain=makeFunction finalArgs target
       val oldDomain=makeFunction oldArgs target
       val safeInitializer=concretize Live domain oldDomain oldSafe
       val liveInitializer=concretize Safe domain oldDomain oldLive
       val safe=makeFrontierRepresentation Safe false tree domain finalArgs liveInitializer safeInitializer
       val live=makeFrontierRepresentation Live false tree domain finalArgs liveInitializer safeInitializer
       val nextSafe=D.delay(fn()=>force(#1(L.force safe)))
       val nextLive=D.delay(fn()=>force(#1(L.force live)))
       val safeEvals=D.delay(fn()=>force(#2(L.force safe)))
       val liveEvals=D.delay(fn()=>force(#2(L.force live)))
       val commentary=F.fromList[SASearch(Safe,name,size,safeEvals),SASearch(Live,name,size,liveEvals)]
       val done=F.defer(fn()=>if sequenceGaveUp sequence then
           let val expanded=head(finalExpansion statics(singleton finalDomain)(singleton oldDomain)(singleton oldSafe))
               val result=cell(SAResult(name,finalDomain,expanded))
           in F.cons(cell(SAGiveUp(singleton name)),singleton result)end
         else singleton(cell(SAResult(name,finalDomain,nextSafe))))
       val rest=F.defer(fn()=>if finished then done else
           nonRecursiveSearch statics name(sequenceTail sequence)args target finalArgs nextSafe nextLive tree)
   in F.append commentary rest end)
 fun nonRecursiveStartup statics name domain tree=F.defer(fn()=>
   let val args=functionArguments domain
       val(_,_,low,high,scale)=staticLimits statics
       val sequence=sizeSequence(staticSizes statics)scale(singleton args)low high
       val(_,initialArgs)=force(nextNonRecursive sequence)
       val target=functionResult domain
       val initial=makeFunction initialArgs target
       val result=nonRecursiveSearch statics name sequence initialArgs target args(bottomRoute initial)(topRoute initial)tree
   in F.append(makeSizeInformation sequence(singleton name))result end)
 fun fixAtSizeLive statics live names domains bigArgs targets trees minOne maxZero sizes level=F.defer(fn()=>
   let val bigDomains=zipExact makeFunction bigArgs targets
       val bigLive=zip3Exact(concretize Live)bigDomains domains live
       val beta=zipExact pair names bigLive
       val treesOriginal=trees
       val trees=map(substituteAnalysis beta)trees
       val nextWithCounts=zip5Exact(fn tree=>fn domain=>fn args=>fn lower=>fn upper=>
            let val result=makeFrontierRepresentation Live(equalInt level(int 0))tree domain args lower upper
            in pair(D.delay(fn()=>force(#1(L.force result))))(D.delay(fn()=>force(#2(L.force result))))end)
               trees domains bigArgs minOne live
       val(next,counts)=unzip nextWithCounts
       val fixed=andWith equalRoute next live
       val commentary=zip3Exact(fn name=>fn size=>fn count=>cell(SASearch(Live,name,size,count)))names sizes counts
       val rest=F.defer(fn()=>if fixed then fixAtSizeSafe statics next next names domains bigArgs targets treesOriginal minOne maxZero sizes level
              else fixAtSizeLive statics next names domains bigArgs targets treesOriginal minOne maxZero sizes level)
       (* Keep the unsubstituted trees for the next fixed-point iteration. *)
   in F.append commentary rest end)
 and fixAtSizeSafe statics safe liveFixes names domains bigArgs targets trees minOne maxZero sizes level=F.defer(fn()=>
   let val bigDomains=zipExact makeFunction bigArgs targets
       val bigSafe=zip3Exact(concretize Safe)bigDomains domains safe
       val beta=zipExact pair names bigSafe
       val changed=map(substituteAnalysis beta)trees
       val nextWithCounts=zip5Exact(fn tree=>fn domain=>fn args=>fn lower=>fn upper=>
            let val result=makeFrontierRepresentation Safe(equalInt level(int 0))tree domain args lower upper
            in pair(D.delay(fn()=>force(#1(L.force result))))(D.delay(fn()=>force(#2(L.force result))))end)
               changed domains bigArgs minOne safe
       val(next,counts)=unzip nextWithCounts
       val fixed=andWith equalRoute next safe
       val commentary=zip3Exact(fn name=>fn size=>fn count=>cell(SASearch(Safe,name,size,count)))names sizes counts
       val rest=F.defer(fn()=>if fixed then singleton(cell(SASL(safe,liveFixes)))
           else fixAtSizeSafe statics next liveFixes names domains bigArgs targets trees minOne maxZero sizes level)
   in F.append commentary rest end)
 fun fixMain statics names sequence previousArgs targets finalArgs previousSafe previousLive trees level=F.defer(fn()=>
   let val previousDomains=zipExact makeFunction previousArgs targets
       val finalDomains=zipExact makeFunction finalArgs targets
   in if sequenceEmpty sequence then
       let val gaveUp=sequenceGaveUp sequence
           val points=if gaveUp then finalExpansion statics finalDomains previousDomains previousSafe else previousSafe
           val results=zip3Exact(fn name=>fn domain=>fn route=>cell(SAResult(name,domain,route)))names finalDomains points
       in if gaveUp then F.cons(cell(SAGiveUp names),results)else results end
      else
       let val sizesAndArgs=nextRecursive sequence
           val args=map(fn entry=> #2(force entry))sizesAndArgs
           val sizes=map(fn entry=> #1(force entry))sizesAndArgs
           val domains=zipExact makeFunction args targets
           val currentSafe=zip3Exact(concretize Safe)domains previousDomains previousSafe
           val currentLive=zip3Exact(concretize Live)domains previousDomains previousLive
           val info=fixAtSizeLive statics currentLive names domains finalArgs targets trees currentSafe currentLive sizes level
           val fixes=L.delay(fn()=>case force(last info)of SASL(safe,live)=>(safe,live)|_=>raise Match)
           val safe=F.defer(fn()=> #1(L.force fixes))
           val live=F.defer(fn()=> #2(L.force fixes))
           val rest=fixMain statics names(sequenceTail sequence)args targets finalArgs safe live trees(add level(int 1))
       in F.append(init info)rest end end)
 fun fixStartup statics names domains trees=F.defer(fn()=>
   let val finalArgs=map functionArguments domains
       val(_,_,low,high,scale)=staticLimits statics
       val sequence=sizeSequence(staticSizes statics)scale finalArgs low high
       val initialArgs=map(fn entry=> #2(force entry))(nextRecursive sequence)
       val targets=map functionResult domains
       val initialDomains=zipExact makeFunction initialArgs targets
       val bottoms=map bottomRoute initialDomains
       val result=fixMain statics names sequence initialArgs targets finalArgs bottoms bottoms trees(int 0)
   in F.append(makeSizeInformation sequence names)result end)
 fun analyzeGroups statics beta groups=F.defer(fn()=>case force groups of F.Nil=>F.empty()
   |F.Cons(group,rest)=>
     let val(recursive,definitions)=force group
         fun optimize expr=if hasFlag statics Simp then simplifyAbstract expr else expr
     in if not(force recursive)then
        let val(defname,rhs)=force(head definitions)
            val _=if null(tail definitions)then()else raise Match
            val tree=vectorizeAbstract(optimize(analyzeExpression statics beta rhs))
            val domain=cafDomain(sureLookup equalName(staticDomains statics)"sa(2)"defname)
            val search=nonRecursiveStartup statics defname domain tree
            val route=analysisResult(last search)
            val augmented=F.cons(pair defname(cell(HPoint route)),beta)
            val following=analyzeGroups statics augmented rest
            val commentary=if hasFlag statics ShowHExpr then singleton(cell(SAHExpr(defname,tree)))else F.empty()
        in F.append commentary(F.append search following)end
       else
        let val names=map(fn entry=> #1(force entry))definitions
            val rhss=map(fn entry=> #2(force entry))definitions
            val trees=map(fn rhs=>vectorizeAbstract(optimize(analyzeExpression statics beta rhs)))rhss
            val domains=map(sureLookup equalName(staticDomains statics)"sa(4)")names
            val result=fixStartup statics names(map cafDomain domains)trees
            val fixes=map analysisResult(filter isAnalysisResult result)
            val augmented=F.append(zipExact(fn name=>fn point=>pair name(cell(HPoint point)))names fixes)beta
            val following=analyzeGroups statics augmented rest
            val commentary=if hasFlag statics ShowHExpr then
                zipExact(fn name=>fn tree=>cell(SAHExpr(name,tree)))names trees else F.empty()
        in F.append commentary(F.append result following)end end)
 fun undoCAFInformation values=flatMap(fn value=>case force value of
    SAResult(name,domain,point)=>singleton(cell(SAResult(name,uncafDomain domain,point)))
   |SASearch(_,_,size,_)=>if less size(int 2)then F.empty()else singleton value
   |SASizes(_,used,unused)=>
       if null unused andalso isSingletonList used then
          let val(_,args)=force(head used)in if null args then F.empty()else singleton value end
       else singleton value
   |SAHExpr _=>singleton value|SAGiveUp _=>singleton value|_=>raise Match)values
