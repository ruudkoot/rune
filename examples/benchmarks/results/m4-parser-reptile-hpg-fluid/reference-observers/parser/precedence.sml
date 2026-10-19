 and hsDoExpr stack env tokens=L.delay(fn()=>
   let val parsed=L.force(hsAExprOrOp env tokens)
       val valid=case parsed of POk _=>true|PFail _=>false
       val incoming=L.delay(fn()=>case parsed of POk(_,_,value)=>value|_=>raise Fail"hsDoExpr(3)")
       val remainder=L.delay(fn()=>case parsed of POk(_,rest,_)=>L.force rest|_=>raise Fail"hsDoExpr(2)")
       val failure=L.delay(fn()=>case parsed of PFail error=>L.force error|_=>raise Fail"hsDoExpr(1)")
       val incomingPriority=L.delay(fn()=>D.force(lookup env(thd3(L.force incoming))
           defaultFixity))
       fun opIn()=D.force(fst3(L.force incoming))
       fun priorIn()=let val(_,p)=L.force incomingPriority in D.force p end
       fun assocIn()=let val(a,_)=L.force incomingPriority in D.force a end
       fun shift()=L.force(hsDoExpr(L.force incoming::stack)env remainder)
       fun makeEntry expression=D.delay(fn()=>(cell false,expression,text""))
       fun two first second rest=
         if valid andalso(D.force(fst3 first)orelse D.force(fst3 second))then shift()
         else L.force(hsDoExpr(makeEntry(node2 ExprApp(snd3 second)(snd3 first))::rest)env tokens)
   in case stack of
       first::second::third::rest=>
         let val priority=L.delay(fn()=>D.force(lookup env(thd3 second)defaultFixity))
             fun prior()=let val(_,p)=L.force priority in D.force p end
             fun assoc()=let val(a,_)=L.force priority in D.force a end
             fun reduce()=L.force(hsDoExpr(makeEntry(node2 ExprApp
                 (node2 ExprApp(snd3 second)(snd3 third))(snd3 first))::rest)env tokens)
         in if valid andalso D.force(fst3 second)andalso opIn()andalso prior()>priorIn()then reduce()
            else if valid andalso D.force(fst3 second)andalso opIn()andalso prior()=priorIn()then
              if assoc()=InfixL andalso assocIn()=InfixL then reduce()
              else if assoc()=InfixR andalso assocIn()=InfixR then shift()
              else PFail(firstToken tokens)
            else if not valid andalso D.force(fst3 second)then reduce()
            else two first second(third::rest)
         end
      |first::second::rest=>two first second rest
      |[first]=>if valid then shift()else POk(env,tokens,snd3 first)
      |[]=>if valid then shift()else PFail failure
   end)
 val hsPrecTable=F.fromList(List.map(fn(name,assoc,priority)=>(text name,pair(cell assoc)(cell priority)))[("-",InfixL,6),("+",InfixL,6),("*",InfixL,7),("div",InfixN,7),("mod",InfixN,7),("<",InfixN,4),("<=",InfixN,4),("==",InfixN,4),("/=",InfixN,4),(">=",InfixN,4),(">",InfixN,4),("C:",InfixR,5),("++",InfixR,5),("\\",InfixN,5),("!!",InfixL,9),(".",InfixR,9),("^",InfixR,8),("elem",InfixN,4),("notElem",InfixN,4),("||",InfixR,2),("&&",InfixR,3)])
 fun parserTest tokens=paModule hsPrecTable tokens
