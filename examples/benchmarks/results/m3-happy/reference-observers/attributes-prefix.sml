 structure AG=
 struct
  datatype token=LBrace|RBrace|Where|Semicolon|Eq|SelfRef of text
    |SubRef of int D.t*text|RightRef of text|Unknown of text|EOF
  datatype rule=SelfAssign of text*token F.seq
    |SubAssign of(int D.t*text)*token F.seq
    |RightmostAssign of text*token F.seq
    |Conditional of token F.seq
  datatype semanticNode=Terminal of token|ErrorToken of int
    |S4 of rule F.seq|S6 of rule D.t|S7 of token F.seq
  type semantic=semanticNode D.t
  datatype stackNode=Stk of semantic*stackNode L.delay
  type stack=stackNode L.delay
  datatype state=State of int->int->token->state->statesNode L.delay->stack->text->int->semantic X.result
  and statesNode=States of state*statesNode L.delay
  type states=statesNode L.delay
  fun return value _ _=X.Ok value
  fun bind parser next chars line=
    case parser chars line of X.Ok value=>next value chars line|X.Failed error=>X.Failed error
  fun push value tail=L.delay(fn()=>Stk(value,tail))
  fun pop stack=case L.force stack of Stk(value,tail)=>(value,tail)
  fun pushState value tail=L.delay(fn()=>States(value,tail))
  fun popState stack=case L.force stack of States(value,tail)=>(value,tail)
  fun dropStack 0 stack=stack
    |dropStack n stack=let val(_,tail)=pop stack in dropStack(n-1)tail end
  fun dropStates 0 states=states
    |dropStates n states=let val(_,tail)=popState states in dropStates(n-1)tail end
  fun get4 value=case D.force value of S4 x=>x|_=>internal()
  fun get6 value=case D.force value of S6 x=>x|_=>internal()
  fun get7 value=case D.force value of S7 x=>x|_=>internal()
  fun terminal value=case D.force value of Terminal x=>x|_=>internal()
  fun selfName(SelfRef value)=value|selfName _=internal()
  fun subName(SubRef value)=value|subName _=internal()
  fun rightName(RightRef value)=value|rightName _=internal()
  fun span predicate chars=
    case uncons chars of NONE=>([],chars)
     |SOME(c,rest)=>if predicate c then
         let val(values,after)=span predicate rest in(c::values,after)end else([],chars)
  fun unknown cont chars line=
    let fun loop reversed chars=case uncons chars of NONE=>(List.rev reversed,chars)
          |SOME(#"$",rest)=>(case uncons rest of SOME(c,_)=>if c<> #"$"andalso not(Char.isDigit c)
                then loop(#"$"::reversed)rest else(List.rev reversed,chars)
             |NONE=>loop(#"$"::reversed)rest)
          |SOME(c,rest)=>if Char.isSpace c orelse List.exists(fn d=>c=d)[#"{",#"}",#";",#"="]
                  then(List.rev reversed,chars)else loop(c::reversed)rest
        val(value,rest)=loop[]chars
    in cont(Unknown(F.defer(fn()=>F.fromList value)))rest line end
  fun attribute cont build chars line=
    case uncons chars of SOME(#".",rest)=>
       (case uncons rest of SOME(c,after)=>
          if Char.isLower c then
            let val(name,tail)=span(fn c=>Char.isAlphaNum c orelse c= #"'")after
            in cont(build(F.defer(fn()=>F.fromList(c::name))))tail line end
          else X.Failed(X.text"bad attribute identifier")
        |NONE=>cont(build emptyText)chars line)
     |_=>cont(build emptyText)chars line
  fun lexer cont chars line=
    case uncons chars of NONE=>cont EOF chars line
     |SOME(c,rest)=>
       if c= #"{"then cont LBrace rest line
       else if c= #"}"then cont RBrace rest line
       else if c= #";"then cont Semicolon rest line
       else if c= #"="then cont Eq rest line
       else if c= #"w"then(case textPrefix(String.explode"where")chars of
           SOME after=>cont Where after line|NONE=>unknown cont chars line)
       else if c= #"$"then(case uncons rest of
          SOME(#"$",after)=>attribute cont SelfRef after line
         |SOME(#">",after)=>attribute cont RightRef after line
         |_=>let val(digits,after)=span Char.isDigit rest
              in if null digits then unknown cont chars line
                 else attribute cont(fn name=>SubRef(D.delay(fn()=>
                   List.foldl(fn(c,n)=>10*n+Char.ord c-48)0 digits),name))after line end)
       else if Char.isSpace c then lexer cont(dropText Char.isSpace rest)line
       else unknown cont chars line
