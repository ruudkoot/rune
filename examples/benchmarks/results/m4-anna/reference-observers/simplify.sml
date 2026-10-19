
 fun equalAbstract left right=case(force left,force right)of
    (HVar a,HVar b)=>equalName a b|(HPoint a,HPoint b)=>equalRoute a b
   |(HApp(a,b),HApp(c,d))=>equalAbstract a c andalso equalAbstract b d
   |(HVAp(a,xs),HVAp(b,ys))=>equalAbstract a b andalso equalLists equalAbstract xs ys
   |(HLam(xs,a),HLam(ys,b))=>equalLists equalName xs ys andalso equalAbstract a b
   |(HMeet xs,HMeet ys)=>equalLists equalAbstract xs ys
   |(HTable xs,HTable ys)=>equalLists(fn x=>fn y=>
        let val(a,b)=force x val(c,d)=force y in equalRoute a c andalso equalAbstract b d end)xs ys
   |_=>false
 fun vectorizeAbstract expression:hexpr=D.delay(fn()=>case force expression of
    HLam(variables,body)=>(case force body of HLam(more,body)=>
         force(vectorizeAbstract(cell(HLam(F.append variables more,body))))
       |_=>HLam(variables,vectorizeAbstract body))
   |HApp(f,arg)=>(case force f of HTable table=>
         HApp(cell(HTable(mapSecond vectorizeAbstract table)),vectorizeAbstract arg)
       |_=>case force(vectorizeAbstract f)of
          HVAp(function,args)=>HVAp(function,F.append args(singleton(vectorizeAbstract arg)))
         |HPoint point=>HVAp(cell(HPoint point),singleton(vectorizeAbstract arg))
         |HVar variable=>HVAp(cell(HVar variable),singleton(vectorizeAbstract arg))
         |other=>HApp(cell other,vectorizeAbstract arg))
   |HVar _=>force expression|HPoint _=>force expression
   |HMeet expressions=>HMeet(map vectorizeAbstract expressions)|_=>raise Match)
 fun optimizeAbstract expression:hexpr=D.delay(fn()=>case force expression of
    HMeet expressions=>force(optimizeAbstractMeet expressions)
   |HApp(a,b)=>force(optimizeAbstractApplication(optimizeAbstract a)(optimizeAbstract b))
   |HPoint _=>force expression|HVar _=>force expression
   |HLam(variables,body)=>HLam(variables,optimizeAbstract body)
   |HTable table=>HTable(mapSecond optimizeAbstract table)|_=>raise Match)
 and optimizeAbstractMeet expressions:hexpr=D.delay(fn()=>
   let val simplified=map optimizeAbstract expressions
       fun split state expression=let val(literals,other)=force state
         in case force expression of HPoint p=>pair(F.cons(p,literals))other
          |_=>pair literals(F.cons(expression,other))end
       val(literals,other)=force(foldLeft split(pair(F.empty())(F.empty()))simplified)
       val literal=foldRight1 joinRoute literals
   in if null literals then HMeet simplified
      else if isTopRoute literal then HPoint literal
      else if isBottomRoute literal then force(makeAbstractMeet(cell(HPoint literal))other)
      else force(makeAbstractMeet(cell(HPoint literal))(F.cons(cell(HPoint literal),other)))end)
 and optimizeAbstractApplication left right:hexpr=D.delay(fn()=>case(force left,force right)of
    (HTable table,HPoint p)=>force(optimizeAbstract(sureLookup equalRoute table"siHOpt_app"p))
   |(HPoint f,HPoint x)=>HPoint(applyRoute f(singleton x))|_=>HApp(left,right))
 fun simplifyAbstract expression:hexpr=D.delay(fn()=>
   let val next=optimizeAbstract expression
   in if equalAbstract expression next then force expression else force(simplifyAbstract next)end)
