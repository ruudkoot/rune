 (* Kept in the action functions' mutual-recursion group. *)
 and newToken action states stack=
   X.lexer(fn token=>
     let fun cont i=action i i token(State action)states stack
     in case token of
        X.EOF=>cont 40
       |X.Info(_,id)=>(case D.force id of X.Id=>cont 17|X.Code=>cont 33|_=>parseError token)
       |X.Num(_,id)=>if D.force id=X.Number then cont 34 else parseError token
       |X.KW id=>(case D.force id of
          X.TokenType=>cont 18|X.TokenSpec=>cont 19|X.Name=>cont 20|X.Partial=>cont 21
         |X.Lexer=>cont 22|X.ImportedIdentity=>cont 23|X.Monad=>cont 24
         |X.Nonassoc=>cont 25|X.Left=>cont 26|X.Right=>cont 27|X.Prec=>cont 28
         |X.Expect=>cont 29|X.Error=>cont 30|X.Attribute=>cont 31|X.AttributeType=>cont 32
         |X.Colon=>cont 35|X.SemiColon=>cont 36|X.DoubleColon=>cont 37
         |X.DoublePercent=>cont 38|X.Bar=>cont 39|_=>parseError token)
     end)
 and shift action 1 token st states stack=
       let val(value,_)=pop stack
           val i=case D.force value of ErrorToken i=>i|_=>internal()
       in action i i token(State action)(pushState st states)stack end
   |shift action _ token st states stack=
       newToken action(pushState st states)(push(D.delay(fn()=>Terminal token))stack)
 and goto action j token _=action j j token(State action)
 and spec0 nt value j token st states stack=
   if j=1 then failure j token st states stack
   else let val State action=st
        in action nt j token st(pushState st states)(push value stack)end
 and spec1 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val(base,_)=popState states val State action=base
            val(v1,rest)=pop stack val value=reduce v1
        in action nt j token base states(push value rest)end
 and spec2 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val(_,states')=popState states
            val(base,_)=popState states' val State action=base
            val(v1,rest)=pop stack val(v2,rest)=pop rest val value=reduce v1 v2
        in action nt j token base states'(push value rest)end
 and spec3 nt reduce j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates 2 states
            val(base,_)=popState states' val State action=base
            val(v1,rest)=pop stack val(v2,rest)=pop rest val(v3,rest)=pop rest
            val value=reduce v1 v2 v3
        in action nt j token base states'(push value rest)end
 and reduce k nt fnc j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates(k-1)states
            val(base,_)=popState states' val State action=base
            val result=fnc stack val _=ignore(L.force result)
        in action nt j token base states' result end
 and monadReduce k nt fnc j token st states stack=
   if j=1 then failure j token st states stack
   else let val states'=dropStates k(pushState st states)
            val(base,_)=popState states' val State action=base
            val rest=dropStack k stack
        in X.bind(fnc stack token)(fn value=>action nt j token base states'(push value rest))end
 and accept j _ _ _ stack=
   let val(value,rest)=pop stack
       val result=if j=1 then #1(pop rest)else value
   in X.return result end
 and failure 1 token _ _ _=parseError token
   |failure i token(st as State action)states stack=
      action 1 1 token st states(push(D.delay(fn()=>ErrorToken i))stack)
 and parseError _ chars line=X.Failed(X.text(Int.toString line^": Parse error\n"))
 fun parse chars line=
   X.bind(newToken action_0
       (L.delay(fn()=>internal()):states)(L.delay(fn()=>internal()):stack))
      (fn value=>X.return(get4 value))chars line
