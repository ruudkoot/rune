
 fun evaluateSearchConstant expression arguments:route=D.delay(fn()=>case force expression of
    HLam _=>force(evaluateExact expression arguments)
   |HPoint point=>if null arguments then force point else force(evaluateConstant(cell(HVAp(expression,arguments))))
   |_=>raise Match)
 fun applySearch info arguments expression:route=D.delay(fn()=>case force info of F.Nil=>raise Match
   |F.Cons(entry,rest)=>(case force entry of
       A2=>if null rest then force(evaluateSearchConstant expression arguments)else raise Match
      |ALo1=>if null rest then force(dataLow1(evaluateSearchConstant expression arguments))else raise Match
      |ALo2=>if null rest then force(dataLow2(evaluateSearchConstant expression arguments))else raise Match
      |AMid2=>if null rest then force(dataMiddle2(evaluateSearchConstant expression arguments))else raise Match
      |AHi1(n,index,target)=>
        let val result=evaluateSearchConstant expression(take n arguments)
            val high=dataHigh1(bottomRoute target)index result
        in force(applySearch rest(drop n arguments)(cell(HPoint high)))end
      |AHi2(n,index,target)=>
        let val result=evaluateSearchConstant expression(take n arguments)
            val high=dataHigh2(bottomRoute target)index result
        in force(applySearch rest(drop n arguments)(cell(HPoint high)))end))
 fun searchGeneric mode expression small big bounds info naive:frontier=D.delay(fn()=>
   let val Min1Max0(_,ones,zeros)=force bounds
       val initialZero=if naive then singleton(cell(MkFrel(map topRoute small)))else zeros
       val initialOne=if naive then singleton(cell(MkFrel(map bottomRoute small)))else ones
       fun makeBigger routes small big=F.defer(fn()=>case(force small,force big)of(F.Nil,F.Nil)=>routes
         |(F.Cons(s,ss),F.Cons(b,bs))=>(case force routes of F.Cons(r,rs)=>
              F.cons(concretize mode b s r,makeBigger rs ss bs)|_=>raise Match)
         |_=>raise Match)
       fun loop trialZero trialOne fromTop randoms=L.delay(fn()=>
         case selectFrontier(L.force(headControl randoms))trialOne trialZero fromTop of
           NONE=>(insertionSort compareFrel trialZero,insertionSort compareFrel trialOne)
          |SOME chosen=>
            let val MkFrel args=force chosen
                val proper=makeBigger args small big
                val evaluated=applySearch info(map(fn point=>cell(HPoint point))proper)expression
                val next=tailControl randoms
            in case force evaluated of
                One=>L.force(loop(reviseMaximum small trialZero chosen)trialOne false next)
               |Zero=>L.force(loop trialZero(reviseMinimum small trialOne chosen)true next)
               |_=>panic"fsFs_aux"end)
       val(finalZero,finalOne)=L.force(loop initialZero initialOne true(randomIntegers(int 1)(int 2)))
   in Min1Max0(length small,finalOne,finalZero)end)
 fun findGeneric mode expression domain small big bounds n info naive:representation=D.delay(fn()=>
   let val(arguments,target)=case force domain of Func(args,target)=>(args,target)|_=>raise Match
       fun high targets previous double=
         let val domains=map(uncurryDomain arguments)targets
             val arity=length arguments
             val indices=intsFromTo(int 0)(subtract(length targets)(int 1))
             val entries=zip3Exact(fn d=>fn target=>fn previous=>triple d target previous)domains targets previous
         in zipExact(fn entry=>fn index=>let val(d,target,previous)=force entry
               val step=cell(if double then AHi2(arity,index,target)else AHi1(arity,index,target))
            in findGeneric mode expression d small big previous arity(F.append info(singleton step))naive end)entries indices end
   in case(force target,force bounds)of
       (Two,RepTwo frontier)=>RepTwo(searchGeneric mode expression small big frontier(F.append info(singleton(cell A2)))naive)
      |(Lift1 targets,Rep1(frontier,previous))=>
          Rep1(searchGeneric mode expression small big frontier(F.append info(singleton(cell ALo1)))naive,
            high targets previous false)
      |(Lift2 targets,Rep2(frontier,middle,previous))=>
          Rep2(searchGeneric mode expression small big frontier(F.append info(singleton(cell ALo2)))naive,
            searchGeneric mode expression small big middle(F.append info(singleton(cell AMid2)))naive,
            high targets previous true)
      |_=>raise Match end)
 fun makeFrontierRepresentation mode naive expression domain big lower upper=L.delay(fn()=>
   let val caf=case force domain of Func(args,_)=>null args|_=>true
   in if caf then
       let val result=evaluateConstant expression
           val normalized=D.delay(fn()=>case force result of Rep rep=>force(constantRepresentation rep)|_=>force result)
       in(normalized,int 0)end
      else
       let val small=case force domain of Func(args,_)=>args|_=>raise Match
           val upper=case force upper of Rep rep=>rep|_=>raise Match
           val lower=case force lower of Rep rep=>rep|_=>raise Match
           val bounds=combineBounds upper lower
       in if isDataFunction domain then
          let val result=findData mode expression domain small big bounds(fn x=>x)naive
               (fn()=>panic"no inherited min1")(F.empty())
              val route=D.delay(fn()=>Rep(#1(L.force result)))
              val count=D.delay(fn()=>force(length(#2(L.force result))))
          in(route,count)end
          else(cell(Rep(findGeneric mode expression domain small big bounds(int 0)(F.empty())naive)),int ~1)
       end end)
