
 fun analyzeExpression statics beta tree:hexpr=D.delay(fn()=>
   let val(dtau,expression)=force tree
   in case force expression of AConstr _=>panic"sa: AConstr encountered"|ALet _=>panic"sa: ALet encountered"
      |ANum _=>HPoint(cell One)
      |AAp(a,b)=>HApp(analyzeExpression statics beta a,analyzeExpression statics beta b)
      |ALam(variables,body)=>HLam(variables,analyzeExpression statics beta body)
      |AVar v=>
        let val first=force(head v)
            val constructor=Char.isUpper first val variable=Char.isLower first val function=first= #"_"
            val lookup=lookupAssociation equalName beta v
            val accounted=case force lookup of Just _=>true|Nothing=>false
            fun lookupResult()=case force lookup of Just e=>e|_=>raise Match
            fun instantiatedConstructor()=
              let val simple=sureLookup equalName(staticExpressions statics)"sa(5)"v
                  val usage=getDomainInstantiations simple dtau
              in constructorInstance(hasFlag statics SimpleInv)
                  (sureLookup equalName(staticConstructors statics)"sa(7)"v)simple usage end
            fun instantiatedFunction()=
              let val simple=sureLookup equalName(staticExpressions statics)"sa(5)"v
                  val usage=getDomainInstantiations simple dtau
                  val(poly,_,_,_,_)=staticLimits statics
                  val point=D.delay(fn()=>case force(lookupResult())of HPoint p=>force p|_=>raise Match)
              in makePolymorphicInstance(not(hasFlag statics NoBaraki))poly Safe simple usage point end
        in if constructor then HPoint(instantiatedConstructor())
           else if variable then if accounted then force(lookupResult())else HVar v
           else if function then if accounted then
              HPoint(instantiatedFunction())
             else HVar v
           else panic"sa(var)"end
      |ACase(switch,alternatives)=>
        let val(swtype,swexpr)=force switch
            val known=case force swexpr of AVar v=>Char.isLower(force(head v))andalso
                any(equalName v)(map(fn entry=> #1(force entry))beta)|_=>false
            fun knownPoint()=D.delay(fn()=>case force swexpr of AVar v=>
                (case force(sureLookup equalName beta"sa(??)"v)of HPoint p=>force p|_=>raise Match)|_=>raise Match)
            val swdomain=defaultDomain swtype
            val points=allRoutes swdomain
            val top=topRoute swdomain
            val bottom=cell(HPoint(bottomRoute(defaultDomain dtau)))
            val names=map(fn entry=> #1(force entry))alternatives
            val simple=map(sureLookup equalName(staticExpressions statics)"sa(9)")names
            val simpleTargets=map(fn d=>D.delay(fn()=>case force d of DXFunc(_,target)=>force target|_=>force d))simple
            val instances=map(fn d=>getDomainInstantiations d swtype)simpleTargets
            val domains=zipExact applyDomainSubstitution instances simple
            val components=map(sureLookup equalName(staticConstructors statics)"sa(10)")names
            val actual=zip3Exact(constructorInstance(hasFlag statics SimpleInv))components simple instances
            val indices=intsFromTo(int 0)(subtract(length alternatives)(int 1))
            val info=map(fn n=>
              let val con=nth actual n val domain=nth domains n
                  val(_,alternative)=force(nth alternatives n)
                  val(params,rhs)=force alternative
                  val caf=cell(case force con of Rep _=>false|_=>true)
              in cell(con,domain,caf,params,rhs)end)indices
            fun inverse con domain caf point=F.defer(fn()=>if force caf then
                if equalRoute point top then singleton(F.empty())else F.empty()
              else map(fn frel=>let val MkFrel args=force frel in args end)
                (maximumInverse(hasFlag statics SimpleInv)domain con point))
            fun outval point=
              let fun one n=
                    let val(con,domain,caf,params,rhs)=force(nth info n)
                        val envs=map(fn args=>zipExact pair params(map(fn p=>cell(HPoint p))args))(inverse con domain caf point)
                    in map(fn env=>analyzeExpression statics(F.append env beta)rhs)envs end
                  val value=makeAbstractMeet bottom(flatMap one indices)
              in pair point value end
        in if known andalso not(hasFlag statics NoCaseOpt)then
              force(#2(force(outval(knownPoint()))))
           else HApp(cell(HTable(map outval points)),analyzeExpression statics beta switch)end
   end)
