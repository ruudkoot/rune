
 type memo=(routeNode F.seq*route)F.seq
 fun dataIsZero point=case force point of Zero=>true|One=>false|_=>raise Match
 fun dataLow1 point:route=D.delay(fn()=>case force point of Stop1=>Zero|Up1 _=>One|_=>raise Match)
 fun dataLow2 point:route=D.delay(fn()=>case force point of Stop2=>Zero|Up2=>One|UpUp2 _=>One|_=>raise Match)
 fun dataMiddle2 point:route=D.delay(fn()=>case force point of Stop2=>Zero|Up2=>Zero|UpUp2 _=>One|_=>raise Match)
 fun dataHigh1 bottom n point:route=D.delay(fn()=>case force point of Stop1=>force bottom|Up1 rs=>force(nth rs n)|_=>raise Match)
 fun dataHigh2 bottom n point:route=D.delay(fn()=>case force point of Stop2=>force bottom|Up2=>force bottom
   |UpUp2 rs=>force(nth rs n)|_=>raise Match)
 fun improveData coerce memo domains naive maxZero minOne=L.delay(fn()=>
   let val(zeros,ones)=L.force(splitBy(fn entry=>let val(_,result)=force entry in dataIsZero(coerce result)end)memo)
       val zeroMaximum=maximal belowFrel(map(fn entry=>let val(args,_)=force entry in cell(MkFrel args)end)zeros)
       val oneMinimum=minimal belowFrel(map(fn entry=>let val(args,_)=force entry in cell(MkFrel args)end)ones)
       val zeroBase=if naive then singleton(cell(MkFrel(map topRoute domains)))else maxZero
       val oneBase=if naive then singleton(cell(MkFrel(map bottomRoute domains)))else minOne
       val newZero=insertionSort compareFrel(frontierMaximumIntersection zeroBase(maxZeroFromMinOne domains oneMinimum))
       val newOne=insertionSort compareFrel(frontierMinimumIntersection oneBase(minOneFromMaxZero domains zeroMaximum))
   in(newZero,newOne)end)
 fun searchData mode expression small big previousOne previousZero coerce=L.delay(fn()=>
   let fun loop trialZero trialOne fromTop memo randoms=L.delay(fn()=>
         let val random=L.force(headControl randoms)
         in case selectFrontier random trialOne trialZero fromTop of
           NONE=>(insertionSort compareFrel trialZero,insertionSort compareFrel trialOne,memo)
          |SOME chosen=>
            let val MkFrel args=force chosen
                val proper=zip3Exact(concretize mode)big small args
                val evaluated=evaluateExact expression(map(fn point=>cell(HPoint point))proper)
                val result=coerce evaluated
                val newMemo=F.cons(pair args evaluated,memo)
                val next=tailControl randoms
            in case force result of
                One=>L.force(loop(reviseMaximum small trialZero chosen)trialOne false newMemo next)
               |Zero=>L.force(loop trialZero(reviseMinimum small trialOne chosen)true newMemo next)
               |_=>panic"fdFs_aux"end end)
       val result=loop previousZero previousOne true(F.empty())(randomIntegers(int 1)(int 2))
       val(zero,one,memo)=L.force result
   in(makeFrontier(length small)one zero,memo)end)
 and headControl values=case L.force values of C.Nil=>raise Empty|C.Cons(x,_)=>x
 and tailControl values=C.defer(fn()=>case L.force values of C.Nil=>raise Empty|C.Cons(_,rest)=>rest)
 fun findData mode expression domain small big previous coerce naive inherited memo=L.delay(fn()=>
   let val(_,target)=case force domain of Func(args,target)=>(args,target)|_=>raise Match
       fun low previous coerce memo=L.delay(fn()=>
         let val Min1Max0(_,ones,zeros)=force previous
             val(betterZero,betterOne)=L.force(improveData coerce memo small naive zeros ones)
         in L.force(searchData mode expression small big betterOne betterZero coerce)end)
   in case(force target,force previous)of
       (Two,RepTwo frontier)=>let val(result,more)=L.force(low frontier coerce memo)
          in(cell(RepTwo result),more)end
      |(Lift1 targets,Rep1(frontier,highs))=>
         let fun lowCoerce x=dataLow1(coerce x)
             val(lo,more)=L.force(low frontier lowCoerce memo)
             val useful=filter(fn entry=>let val(_,result)=force entry in not(dataIsZero(lowCoerce result))end)(F.append more memo)
             val Min1Max0(_,ones,_)=force lo
             val(newHighs,highMemo)=L.force(findDataHigh mode expression small big targets highs coerce useful false(fn()=>ones)naive)
         in(cell(Rep1(lo,newHighs)),F.append more highMemo)end
      |(Lift2 targets,Rep2(frontier,middle,highs))=>
         let fun lowCoerce x=dataLow2(coerce x)
             val(lo,more)=L.force(low frontier lowCoerce memo)
             val useful=filter(fn entry=>let val(_,result)=force entry in not(dataIsZero(lowCoerce result))end)(F.append more memo)
             fun middleCoerce x=dataMiddle2(coerce x)
             val(mid,middleMore)=L.force(low middle middleCoerce useful)
             val usefulMiddle=filter(fn entry=>let val(_,result)=force entry
               in not(dataIsZero(middleCoerce result))end)(F.append middleMore useful)
             val Min1Max0(_,ones,_)=force mid
             val(newHighs,highMemo)=L.force(findDataHigh mode expression small big targets highs coerce usefulMiddle true(fn()=>ones)naive)
         in(cell(Rep2(lo,mid,newHighs)),F.append more(F.append middleMore highMemo))end
      |_=>raise Match end)
 and findDataHigh mode expression small big targets previous coerce initial double inherited naive=L.delay(fn()=>
   let val domains=map(uncurryDomain small)targets
       val indices=intsFromTo(int 0)(subtract(length targets)(int 1))
       val first=zip3Exact(fn index=>fn rep=>fn bottom=>triple index rep bottom)indices previous(map bottomRoute targets)
       val tuples=zipExact(fn first=>fn domain=>let val(n,rep,bottom)=force first
          in cell(domain,n,rep,bottom)end)first domains
       fun one added tuple=
         let val(domain,n,previous,bottom)=force tuple
             fun high point=if double then dataHigh2 bottom n(coerce point)else dataHigh1 bottom n(coerce point)
             val result=findData mode expression domain small big previous high naive inherited(F.append added initial)
             val more=F.defer(fn()=> #2(L.force result))
             val rep=D.delay(fn()=>force(#1(L.force result)))
         in(F.append more added,rep)end
       val(result,highs)=L.force(mapAccumulate one(F.empty())tuples)
   in(highs,result)end)
