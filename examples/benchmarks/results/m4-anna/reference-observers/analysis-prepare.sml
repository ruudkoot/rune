
 val baseAnnotations:(name*hexpr)F.seq=
   let fun frel rs=cell(MkFrel(F.fromList rs))
       fun point arity ones zeros=
          let val frontier=makeFrontier(int arity)ones zeros
              val representation=cell(RepTwo frontier)
              val route=cell(Rep representation)
          in cell(HPoint route)end
       val unary=point 1(singleton(frel[One]))(singleton(frel[Zero]))
       val binary=point 2(singleton(frel[One,One]))(F.cons(frel[Zero,One],singleton(frel[One,Zero])))
       val parallelOr=point 2(F.cons(frel[Zero,One],singleton(frel[One,Zero])))(singleton(frel[Zero,Zero]))
       val items=[("_not",unary),("_+",binary),("_-",binary),("_*",binary),("_/",binary),("_%",binary),
          ("_<",binary),("_<=",binary),("_==",binary),("_~=",binary),("_>=",binary),("_>",binary),
          ("_|",binary),("_&",binary),("_#",parallelOr),("False",cell(HPoint(cell One))),("True",cell(HPoint(cell One)))]
   in F.fromList(List.map(fn(n,value)=>(name n,value))items)end
 val defaultSettings:flags=F.fromList[PolyLim(int 10000),MonoLim(int 10000),LowerLim(int 0),UpperLim(int 1000000),ScaleUp(int 20)]
 fun prepareAnalysisDetailed contents table flags=
   let val(dar,atomic)=parseCore contents
       val(types,expression)=force atomic
       val builtins=map(fn entry=> #1(force entry))baseAnnotations
       val lifted=lambdaLift builtins expression(not(member equalFlag(cell NoPretty)flags))
       val(program,parameters)=L.force lifted
       val(words,checked)=checkTypes baseTypes(singleton(int 1),singleton(int 0))(pair types program)
       val(tree,environment)=case L.force checked of Ok value=>force value|_=>panic"maStrictAn: Typecheck failed -- cannot proceed."
       val typed=etaAbstract tree
       val boolDefinition=cell(name"bool",F.empty(),
           F.fromList[(name"True",F.empty()),(name"False",F.empty())])
       val definitions=F.cons(boolDefinition,types)
       val groups=F.cons(pair(cell false)(singleton(name"bool")),dar)
       val fullEnv=F.append environment(mapSecond(fn scheme=>D.delay(fn()=>case force scheme of Scheme(_,t)=>force t))baseTypes)
       val simple=mapSecond(typeToDomainExpression groups)fullEnv
       val domains=mapSecond defaultDomain simple
       fun flagValue predicate extract=extract(force(head(filter(fn f=>predicate(force f))flags)))
       val poly=flagValue(fn PolyLim _=>true|_=>false)(fn PolyLim n=>n|_=>raise Match)
       val mono=flagValue(fn MonoLim _=>true|_=>false)(fn MonoLim n=>n|_=>raise Match)
       val low=flagValue(fn LowerLim _=>true|_=>false)(fn LowerLim n=>n|_=>raise Match)
       val high=flagValue(fn UpperLim _=>true|_=>false)(fn UpperLim n=>n|_=>raise Match)
       val scale=flagValue(fn ScaleUp _=>true|_=>false)(fn ScaleUp n=>n|_=>raise Match)
       val statics:static=(simple,domains,constructorArguments definitions,parameters,flags,
          (poly,mono,low,high,scale),table)
       val recursiveGroups=analysisGroups(typedToDomainTree groups typed)
   in(statics,undoCAFInformation(analyzeGroups statics baseAnnotations recursiveGroups),
       prettyParsed types program,words)end
 fun prepareAnalysis contents table=
   let val(statics,result,_,_)=prepareAnalysisDetailed(input contents)table defaultSettings
   in(statics,result)end
