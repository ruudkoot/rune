 fun uncurryWithRespect small big:domain=D.delay(fn()=>case(force small,force big)of
    (Two,_)=>force big
   |(Lift1 xs,Lift1 ys)=>Lift1(zipExact uncurryWithRespect xs ys)
   |(Lift2 xs,Lift2 ys)=>Lift2(zipExact uncurryWithRespect xs ys)
   |(Func(xs,x),Func(ys,y))=>
      let val smallArity=length xs val bigArity=length ys
          val(fixedArgs,fixedResult)=if equalInt smallArity bigArity then(ys,y)
            else if less smallArity bigArity then(take smallArity ys,cell(Func(drop smallArity ys,y)))
            else panic"acUncurryWRT"
      in Func(zipExact uncurryWithRespect xs fixedArgs,uncurryWithRespect x fixedResult)end
   |_=>raise Match)
 fun compatible big small=case force small of Two=>true|_=>
   (case(force big,force small)of(Lift1 xs,Lift1 ys)=>andWith compatible xs ys
     |(Lift2 xs,Lift2 ys)=>andWith compatible xs ys
     |(Func(xs,x),Func(ys,y))=>compatible x y andalso andWith compatible xs ys|_=>false)
 fun concretize mode big small point:route=D.delay(fn()=>
   if equalDomain big small then force point else
     let val function=case force small of Func _=>true|_=>false
         val normalized=if function then strongNormalize big else big
         val curried=if function then uncurryWithRespect small normalized else big
     in if not(compatible curried small)then panic"acConc: incompatible domains\n\n"
       else if function then case force point of Rep rep=>
          let val source=concretizeSource mode normalized small rep
              val sourceDomain=strongNormalize(concretizedSourceDomain curried small)
              val target=case force curried of Func(_,target)=>target|_=>raise Match
          in Rep(concretizeTarget mode target sourceDomain source)end|_=>raise Match
       else force(concretizeData mode normalized small point)end)
 and concretizeData mode big small point:route=D.delay(fn()=>case(force big,force small,force point)of
    (_,Two,One)=>force(topRoute big)|(_,Two,Zero)=>force(bottomRoute big)
   |(Lift1 _,Lift1 _,Stop1)=>Stop1
   |(Lift1 xs,Lift1 ys,Up1 rs)=>Up1(zip3Exact(concretize mode)xs ys rs)
   |(Lift2 _,Lift2 _,Stop2)=>Stop2|(Lift2 _,Lift2 _,Up2)=>Up2
   |(Lift2 xs,Lift2 ys,UpUp2 rs)=>UpUp2(zip3Exact(concretize mode)xs ys rs)|_=>raise Match)
 and concretizeTarget mode target current rep:representation=D.delay(fn()=>
   let val(arguments,result)=case force current of Func(args,result)=>(args,result)|_=>raise Match
   in case(force target,force result,force rep)of
      (Two,Two,RepTwo _)=>force rep
     |(Lift1 ds,Two,RepTwo f)=>Rep1(f,map(fn d=>concretizeTarget mode d current rep)ds)
     |(Lift2 ds,Two,RepTwo f)=>Rep2(f,f,map(fn d=>concretizeTarget mode d current rep)ds)
     |(Func(more,result),Two,RepTwo f)=>
        let val increase=length more val newDomain=cell(Func(F.append arguments more,cell Two))
            val increased=increaseArityMode mode increase arguments more f
        in force(concretizeTarget mode result newDomain increased)end
     |(Lift1 targets,Lift1 smallerTargets,Rep1(low,highs))=>
        Rep1(low,concretizeTargetHighs mode arguments smallerTargets targets highs)
     |(Lift2 targets,Lift2 smallerTargets,Rep2(low,middle,highs))=>
        Rep2(low,middle,concretizeTargetHighs mode arguments smallerTargets targets highs)
     |_=>raise Match end)
 and concretizeTargetHighs mode arguments smaller larger highs=
   let val smallDomains=map(uncurryDomain arguments)smaller
       val bigDomains=map(uncurryDomain arguments)larger
       fun required small big:domain=D.delay(fn()=>case(force small,force big)of
           (Func(xs,_),Func(ys,result))=>let val extra=drop(length xs)ys
             in if null extra then force result else Func(extra,result)end|_=>raise Match)
       val targets=zipExact required smallDomains bigDomains
   in zip3Exact(concretizeTarget mode)targets smallDomains highs end
 and increaseArityMode mode increase arguments extra frontier:representation=D.delay(fn()=>
   let val finalArguments=F.append arguments extra
       val rep=cell(RepTwo frontier)
       val special=case mode of Safe=>isBottomRepresentation rep|Live=>isTopRepresentation rep
   in if special then force(case mode of Safe=>bottomRepresentation(cell(Func(finalArguments,cell Two)))
         |Live=>topRepresentation(cell(Func(finalArguments,cell Two))))
      else let val points=case mode of Safe=>map bottomRoute extra|Live=>map topRoute extra
               val Min1Max0(arity,ones,zeros)=force frontier
               fun extend value=let val MkFrel rs=force value in cell(MkFrel(F.append rs points))end
               val newOnes=F.defer(fn()=>case mode of Safe=>minOneFromMaxZero finalArguments(map extend zeros)|Live=>map extend ones)
               val newZeros=F.defer(fn()=>case mode of Safe=>map extend zeros|Live=>maxZeroFromMinOne finalArguments(map extend ones))
           in RepTwo(makeFrontier(add arity increase)newOnes newZeros)end end)
 and concretizeSourceFrontier mode bigArgs smallArgs frontier:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force frontier val used=take arity bigArgs
       fun point mode value=let val MkFrel points=force value
         in cell(MkFrel(zip3Exact(concretize mode)used smallArgs points))end
       val newOnes=F.defer(fn()=>case mode of Safe=>minOneFromMaxZero used(map(point Safe)zeros)|Live=>map(point Live)ones)
       val newZeros=F.defer(fn()=>case mode of Safe=>map(point Safe)zeros|Live=>maxZeroFromMinOne used(map(point Live)ones))
   in Min1Max0(arity,newOnes,newZeros)end)
 and concretizeSource mode big small rep:representation=D.delay(fn()=>case(force big,force small,force rep)of
    (Func(bigArgs,_),Func(smallArgs,result),RepTwo f)=>(case force result of
       Two=>RepTwo(concretizeSourceFrontier mode bigArgs smallArgs f)|_=>raise Match)
   |(Func(bigArgs,bigResult),Func(smallArgs,smallResult),Rep1(low,highs))=>
      (case(force bigResult,force smallResult)of(Lift1 bigTargets,Lift1 smallTargets)=>
        let val highDomainsBig=map(uncurryDomain bigArgs)bigTargets
            val highDomainsSmall=map(uncurryDomain smallArgs)smallTargets
        in Rep1(concretizeSourceFrontier mode bigArgs smallArgs low,
             zip3Exact(concretizeSource mode)highDomainsBig highDomainsSmall highs)end|_=>raise Match)
   |(Func(bigArgs,bigResult),Func(smallArgs,smallResult),Rep2(low,middle,highs))=>
      (case(force bigResult,force smallResult)of(Lift2 bigTargets,Lift2 smallTargets)=>
        let val highDomainsBig=map(uncurryDomain bigArgs)bigTargets
            val highDomainsSmall=map(uncurryDomain smallArgs)smallTargets
        in Rep2(concretizeSourceFrontier mode bigArgs smallArgs low,
             concretizeSourceFrontier mode bigArgs smallArgs middle,
             zip3Exact(concretizeSource mode)highDomainsBig highDomainsSmall highs)end|_=>raise Match)
   |_=>raise Match)
 and concretizedSourceDomain big small:domain=D.delay(fn()=>case(force big,force small)of
    (Func(bigArgs,_),Func(_,result))=>(case force result of Two=>Func(bigArgs,cell Two)
      |Lift1 targets=>let
           val smallArgs=case force small of Func(args,_)=>args|_=>raise Match
           val arity=length smallArgs
           val bigDomains=map(uncurryDomain bigArgs)targets
           val smallDomains=map(uncurryDomain smallArgs)targets
           val results=zipExact concretizedSourceDomain bigDomains smallDomains
           fun dropLow domain:domain=D.delay(fn()=>case force domain of Func(args,result)=>
               let val extra=drop arity args in if null extra then force result else Func(extra,result)end|_=>raise Match)
         in Func(bigArgs,cell(Lift1(map dropLow results)))end
      |Lift2 targets=>let val bigTargets=case force big of Func(_,target)=>target|_=>raise Match
           val bigTargets=case force bigTargets of Lift2 ds=>ds|_=>raise Match
           val smallArgs=case force small of Func(args,_)=>args|_=>raise Match
           val result=concretizedSourceDomain(cell(Func(bigArgs,cell(Lift1 bigTargets))))
               (cell(Func(smallArgs,cell(Lift1 targets))))
         in case force result of Func(args,target)=>(case force target of Lift1 ds=>Func(args,cell(Lift2 ds))|_=>raise Match)|_=>raise Match end
      |_=>raise Match)|_=>raise Match)
 fun makeAbstractInstance mode simplest substitution point=
   let val final=strongNormalize(applyDomainSubstitution substitution simplest)
       val basic=defaultDomain simplest
   in concretize mode final basic point end
