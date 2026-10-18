(* Open prefix of the Happy parser-generator functor. *)
functor BenchHappyFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure X=BenchHappyLexerFn(D)
 structure F=X.F
 type text=X.text
 type rule=text F.seq*text*int D.t*text option D.t
 type production=text*rule F.seq*text option D.t
 datatype directive=
    TokenType of text
   |TokenSpec of(text*text)F.seq
   |TokenName of text*text option D.t*bool D.t
   |TokenLexer of text*text
   |TokenImportedIdentity
   |TokenMonad of text*text*text*text
   |TokenNonassoc of text F.seq
   |TokenRight of text F.seq
   |TokenLeft of text F.seq
   |TokenExpect of int D.t
   |TokenError of text
   |TokenAttributetype of text
   |TokenAttribute of text*text
 datatype ast=AbsSyn of text option D.t*directive F.seq*production F.seq*text option D.t
 datatype semanticNode=
    Terminal of X.token
   |ErrorToken of int
   |S4 of ast D.t
   |S5 of production F.seq
   |S6 of production D.t
   |S7 of rule F.seq
   |S8 of rule D.t
   |S9 of text option D.t
   |S10 of directive F.seq
   |S11 of directive D.t
   |S13 of(text*text)F.seq
   |S14 of(text*text)D.t
   |S15 of text F.seq
 type semantic=semanticNode D.t
 datatype stackNode=Stk of semantic*stackNode L.delay
 type stack=stackNode L.delay
 datatype state=State of int->int->X.token->state->statesNode L.delay->stack->semantic X.parser
 and statesNode=States of state*statesNode L.delay
 type states=statesNode L.delay
 fun internal()=raise Fail"Internal Happy error\n"
 fun reverse values=F.defer(fn()=>
   let fun loop values out=case D.force values of F.Nil=>out
         |F.Cons(x,rest)=>loop rest(F.cons(x,out))
   in loop values(F.empty())end)
 fun singleton value=F.cons(value,F.empty())
 fun push value tail=L.delay(fn()=>Stk(value,tail))
 fun pop stack=case L.force stack of Stk(value,tail)=>(value,tail)
 fun pushState value tail=L.delay(fn()=>States(value,tail))
 fun popState stack=case L.force stack of States(value,tail)=>(value,tail)
 fun dropStack 0 stack=stack
   |dropStack n stack=let val(_,tail)=pop stack in dropStack(n-1)tail end
 fun dropStates 0 states=states
   |dropStates n states=let val(_,tail)=popState states in dropStates(n-1)tail end
 fun info tag value=case D.force value of Terminal(X.Info(text,id))=>
   if D.force id=tag then text else internal()|_=>internal()
 fun number value=case D.force value of Terminal(X.Num(n,id))=>
   if D.force id=X.Number then n else internal()|_=>internal()
 fun get4 value=case D.force value of S4 x=>x|_=>internal()
 fun get5 value=case D.force value of S5 x=>x|_=>internal()
 fun get6 value=case D.force value of S6 x=>x|_=>internal()
 fun get7 value=case D.force value of S7 x=>x|_=>internal()
 fun get8 value=case D.force value of S8 x=>x|_=>internal()
 fun get9 value=case D.force value of S9 x=>x|_=>internal()
 fun get10 value=case D.force value of S10 x=>x|_=>internal()
 fun get11 value=case D.force value of S11 x=>x|_=>internal()
 fun get13 value=case D.force value of S13 x=>x|_=>internal()
 fun get14 value=case D.force value of S14 x=>x|_=>internal()
 fun get15 value=case D.force value of S15 x=>x|_=>internal()
 val unitContext=X.text"()"
 val monadBind=X.text">>="
 val monadReturn=X.text"return"
(* Generated parser's forty source reductions. Special reductions leave the
 * semantic root delayed; generic reductions demand only their stack root. *)
 fun reduction1 stack=L.delay(fn()=>
   let val(v5,s)=pop stack val footer=get9 v5
       val(v4,s)=pop s val productions=get5 v4
       val(_,s)=pop s
       val(v2,s)=pop s val directives=get10 v2
       val(v1,s)=pop s val header=get9 v1
   in Stk(D.delay(fn()=>S4(D.delay(fn()=>AbsSyn(header,reverse directives,reverse productions,footer)))),s)end)
 fun reduction2 v2 v1=D.delay(fn()=>
   let val x=get6 v2 val xs=get5 v1 in S5(F.cons(x,xs))end)
 fun reduction3 v1=D.delay(fn()=>S5(singleton(get6 v1)))
 fun reduction4 stack=L.delay(fn()=>
   let val(v5,s)=pop stack val rules=get7 v5
       val(_,s)=pop s
       val(v3,s)=pop s val code=info X.Code v3
       val(_,s)=pop s
       val(v1,s)=pop s val name=info X.Id v1
   in Stk(D.delay(fn()=>S6(D.delay(fn()=>(name,rules,D.delay(fn()=>SOME code))))),s)end)
 fun reduction5 stack=L.delay(fn()=>
   let val(v6,s)=pop stack val rules=get7 v6
       val(_,s)=pop s val(_,s)=pop s
       val(v3,s)=pop s val code=info X.Code v3
       val(_,s)=pop s
       val(v1,s)=pop s val name=info X.Id v1
   in Stk(D.delay(fn()=>S6(D.delay(fn()=>(name,rules,D.delay(fn()=>SOME code))))),s)end)
 fun reduction6 v3 _ v1=D.delay(fn()=>
   let val rules=get7 v3 val name=info X.Id v1
   in S6(D.delay(fn()=>(name,rules,D.delay(fn()=>NONE))))end)
 fun reduction7 v3 _ v1=D.delay(fn()=>
   let val rest=get7 v3 val first=get8 v1 in S7(F.cons(first,rest))end)
 fun reduction8 v1=D.delay(fn()=>S7(singleton(get8 v1)))
 fun reduction9 stack _ chars line=
   let val(_,s)=pop stack
       val(v3,s)=pop s val code=info X.Code v3
       val(v2,s)=pop s val priority=get9 v2
       val(v1,_)=pop s val names=get15 v1
   in X.Ok(D.delay(fn()=>S8(D.delay(fn()=>(names,code,D.delay(fn()=>line),priority)))))end
 fun reduction10 stack _ chars line=
   let val(v3,s)=pop stack val code=info X.Code v3
       val(v2,s)=pop s val priority=get9 v2
       val(v1,_)=pop s val names=get15 v1
   in X.Ok(D.delay(fn()=>S8(D.delay(fn()=>(names,code,D.delay(fn()=>line),priority)))))end
 fun reduction11 v2 _=D.delay(fn()=>
   let val name=info X.Id v2 in S9(D.delay(fn()=>SOME name))end)
 val reduction12:semantic=D.delay(fn()=>S9(D.delay(fn()=>NONE)))
 fun reduction13 v2 v1=D.delay(fn()=>
   let val x=get11 v2 val xs=get10 v1 in S10(F.cons(x,xs))end)
 fun reduction14 v1=D.delay(fn()=>S10(singleton(get11 v1)))
 fun reduction15 v2 _=D.delay(fn()=>
   let val code=info X.Code v2 in S11(D.delay(fn()=>TokenType code))end)
 fun reduction16 v2 _=D.delay(fn()=>
   let val specs=get13 v2 in S11(D.delay(fn()=>TokenSpec specs))end)
 fun reduction17 v3 v2 _=D.delay(fn()=>
   let val start=get9 v3 val name=info X.Id v2
   in S11(D.delay(fn()=>TokenName(name,start,D.delay(fn()=>false))))end)
 fun reduction18 v3 v2 _=D.delay(fn()=>
   let val start=get9 v3 val name=info X.Id v2
   in S11(D.delay(fn()=>TokenName(name,start,D.delay(fn()=>true))))end)
 fun reduction19 _=D.delay(fn()=>S11(D.delay(fn()=>TokenImportedIdentity)))
 fun reduction20 v3 v2 _=D.delay(fn()=>
   let val second=info X.Code v3 val first=info X.Code v2
   in S11(D.delay(fn()=>TokenLexer(first,second)))end)
 fun reduction21 v2 _=D.delay(fn()=>
   let val monad=info X.Code v2
   in S11(D.delay(fn()=>TokenMonad(unitContext,monad,monadBind,monadReturn)))end)
 fun reduction22 v3 v2 _=D.delay(fn()=>
   let val monad=info X.Code v3 val context=info X.Code v2
   in S11(D.delay(fn()=>TokenMonad(context,monad,monadBind,monadReturn)))end)
 fun reduction23 stack=L.delay(fn()=>
   let val(v4,s)=pop stack val ret=info X.Code v4
       val(v3,s)=pop s val bind=info X.Code v3
       val(v2,s)=pop s val monad=info X.Code v2
       val(_,s)=pop s
   in Stk(D.delay(fn()=>S11(D.delay(fn()=>TokenMonad(unitContext,monad,bind,ret)))),s)end)
 fun reduction24 stack=L.delay(fn()=>
   let val(v5,s)=pop stack val ret=info X.Code v5
       val(v4,s)=pop s val bind=info X.Code v4
       val(v3,s)=pop s val monad=info X.Code v3
       val(v2,s)=pop s val context=info X.Code v2
       val(_,s)=pop s
   in Stk(D.delay(fn()=>S11(D.delay(fn()=>TokenMonad(context,monad,bind,ret)))),s)end)
 fun reduction25 v2 _=D.delay(fn()=>
   let val names=get15 v2 in S11(D.delay(fn()=>TokenNonassoc names))end)
 fun reduction26 v2 _=D.delay(fn()=>
   let val names=get15 v2 in S11(D.delay(fn()=>TokenRight names))end)
 fun reduction27 v2 _=D.delay(fn()=>
   let val names=get15 v2 in S11(D.delay(fn()=>TokenLeft names))end)
 fun reduction28 v2 _=D.delay(fn()=>
   let val count=number v2 in S11(D.delay(fn()=>TokenExpect count))end)
 fun reduction29 v2 _=D.delay(fn()=>
   let val code=info X.Code v2 in S11(D.delay(fn()=>TokenError code))end)
 fun reduction30 v2 _=D.delay(fn()=>
   let val code=info X.Code v2 in S11(D.delay(fn()=>TokenAttributetype code))end)
 fun reduction31 v3 v2 _=D.delay(fn()=>
   let val code=info X.Code v3 val name=info X.Id v2
   in S11(D.delay(fn()=>TokenAttribute(name,code)))end)
 fun reduction32 v1=D.delay(fn()=>
   let val name=info X.Id v1 in S9(D.delay(fn()=>SOME name))end)
 val reduction33:semantic=D.delay(fn()=>S9(D.delay(fn()=>NONE)))
 fun reduction34 v2 v1=D.delay(fn()=>
   let val rest=get13 v2 val first=get14 v1 in S13(F.cons(first,rest))end)
 fun reduction35 v1=D.delay(fn()=>S13(singleton(get14 v1)))
 fun reduction36 v2 v1=D.delay(fn()=>
   let val code=info X.Code v2 val name=info X.Id v1
   in S14(D.delay(fn()=>(name,code)))end)
 fun reduction37 v2 v1=D.delay(fn()=>
   let val rest=get15 v2 val first=info X.Id v1
   in S15(F.cons(D.delay(fn()=>first),rest))end)
 val reduction38:semantic=D.delay(fn()=>S15(F.empty()))
 fun reduction39 v1=D.delay(fn()=>
   let val code=info X.Code v1 in S9(D.delay(fn()=>SOME code))end)
 val reduction40:semantic=D.delay(fn()=>S9(D.delay(fn()=>NONE)))
 fun action_0 symbol=case symbol of
   33=>shift action_3
  |4=>goto action_4
  |16=>goto action_2
  |_=>reduce_40
 and action_1 symbol=case symbol of
   33=>shift action_3
  |16=>goto action_2
  |_=>failure
 and action_2 symbol=case symbol of
   18=>shift action_7
  |19=>shift action_8
  |20=>shift action_9
  |21=>shift action_10
  |22=>shift action_11
  |23=>shift action_12
  |24=>shift action_13
  |25=>shift action_14
  |26=>shift action_15
  |27=>shift action_16
  |29=>shift action_17
  |30=>shift action_18
  |31=>shift action_19
  |32=>shift action_20
  |10=>goto action_5
  |11=>goto action_6
  |_=>failure
 and action_3 symbol=case symbol of
   _=>reduce_39
 and action_4 symbol=case symbol of
   40=>accept
  |_=>failure
 and action_5 symbol=case symbol of
   18=>shift action_7
  |19=>shift action_8
  |20=>shift action_9
  |21=>shift action_10
  |22=>shift action_11
  |23=>shift action_12
  |24=>shift action_13
  |25=>shift action_14
  |26=>shift action_15
  |27=>shift action_16
  |29=>shift action_17
  |30=>shift action_18
  |31=>shift action_19
  |32=>shift action_20
  |38=>shift action_38
  |11=>goto action_37
  |_=>failure
 and action_6 symbol=case symbol of
   _=>reduce_14
 and action_7 symbol=case symbol of
   33=>shift action_36
  |_=>failure
 and action_8 symbol=case symbol of
   17=>shift action_35
  |13=>goto action_33
  |14=>goto action_34
  |_=>failure
 and action_9 symbol=case symbol of
   17=>shift action_32
  |_=>failure
 and action_10 symbol=case symbol of
   17=>shift action_31
  |_=>failure
 and action_11 symbol=case symbol of
   33=>shift action_30
  |_=>failure
 and action_12 symbol=case symbol of
   _=>reduce_19
 and action_13 symbol=case symbol of
   33=>shift action_29
  |_=>failure
 and action_14 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_28
  |_=>reduce_38
 and action_15 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_27
  |_=>reduce_38
 and action_16 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_25
  |_=>reduce_38
 and action_17 symbol=case symbol of
   34=>shift action_24
  |_=>failure
 and action_18 symbol=case symbol of
   33=>shift action_23
  |_=>failure
 and action_19 symbol=case symbol of
   17=>shift action_22
  |_=>failure
 and action_20 symbol=case symbol of
   33=>shift action_21
  |_=>failure
 and action_21 symbol=case symbol of
   _=>reduce_30
 and action_22 symbol=case symbol of
   33=>shift action_50
  |_=>failure
 and action_23 symbol=case symbol of
   _=>reduce_29
 and action_24 symbol=case symbol of
   _=>reduce_28
 and action_25 symbol=case symbol of
   _=>reduce_26
 and action_26 symbol=case symbol of
   17=>shift action_26
  |15=>goto action_49
  |_=>reduce_38
 and action_27 symbol=case symbol of
   _=>reduce_27
 and action_28 symbol=case symbol of
   _=>reduce_25
 and action_29 symbol=case symbol of
   33=>shift action_48
  |_=>reduce_21
 and action_30 symbol=case symbol of
   33=>shift action_47
  |_=>failure
 and action_31 symbol=case symbol of
   17=>shift action_45
  |12=>goto action_46
  |_=>reduce_33
 and action_32 symbol=case symbol of
   17=>shift action_45
  |12=>goto action_44
  |_=>reduce_33
 and action_33 symbol=case symbol of
   _=>reduce_16
 and action_34 symbol=case symbol of
   17=>shift action_35
  |13=>goto action_43
  |14=>goto action_34
  |_=>reduce_35
 and action_35 symbol=case symbol of
   33=>shift action_42
  |_=>failure
 and action_36 symbol=case symbol of
   _=>reduce_15
 and action_37 symbol=case symbol of
   _=>reduce_13
 and action_38 symbol=case symbol of
   17=>shift action_41
  |5=>goto action_39
  |6=>goto action_40
  |_=>failure
 and action_39 symbol=case symbol of
   17=>shift action_41
  |33=>shift action_3
  |6=>goto action_54
  |16=>goto action_55
  |_=>reduce_40
 and action_40 symbol=case symbol of
   _=>reduce_3
 and action_41 symbol=case symbol of
   35=>shift action_52
  |37=>shift action_53
  |_=>failure
 and action_42 symbol=case symbol of
   _=>reduce_36
 and action_43 symbol=case symbol of
   _=>reduce_34
 and action_44 symbol=case symbol of
   _=>reduce_17
 and action_45 symbol=case symbol of
   _=>reduce_32
 and action_46 symbol=case symbol of
   _=>reduce_18
 and action_47 symbol=case symbol of
   _=>reduce_20
 and action_48 symbol=case symbol of
   33=>shift action_51
  |_=>reduce_22
 and action_49 symbol=case symbol of
   _=>reduce_37
 and action_50 symbol=case symbol of
   _=>reduce_31
 and action_51 symbol=case symbol of
   33=>shift action_60
  |_=>reduce_23
 and action_52 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_57
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_53 symbol=case symbol of
   33=>shift action_56
  |_=>failure
 and action_54 symbol=case symbol of
   _=>reduce_2
 and action_55 symbol=case symbol of
   _=>reduce_1
 and action_56 symbol=case symbol of
   17=>shift action_64
  |35=>shift action_65
  |_=>failure
 and action_57 symbol=case symbol of
   _=>reduce_6
 and action_58 symbol=case symbol of
   39=>shift action_63
  |_=>reduce_8
 and action_59 symbol=case symbol of
   28=>shift action_62
  |9=>goto action_61
  |_=>reduce_12
 and action_60 symbol=case symbol of
   _=>reduce_24
 and action_61 symbol=case symbol of
   33=>shift action_70
  |_=>failure
 and action_62 symbol=case symbol of
   17=>shift action_69
  |_=>failure
 and action_63 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_68
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_64 symbol=case symbol of
   35=>shift action_67
  |_=>failure
 and action_65 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_66
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_66 symbol=case symbol of
   _=>reduce_4
 and action_67 symbol=case symbol of
   17=>shift action_26
  |7=>goto action_72
  |8=>goto action_58
  |15=>goto action_59
  |_=>reduce_38
 and action_68 symbol=case symbol of
   _=>reduce_7
 and action_69 symbol=case symbol of
   _=>reduce_11
 and action_70 symbol=case symbol of
   36=>shift action_71
  |_=>reduce_10
 and action_71 symbol=case symbol of
   _=>reduce_9
 and action_72 symbol=case symbol of
   _=>reduce_5
 and reduce_1 j token st states stack=reduce 5 4 reduction1 j token st states stack
 and reduce_2 j token st states stack=spec2 5 reduction2 j token st states stack
 and reduce_3 j token st states stack=spec1 5 reduction3 j token st states stack
 and reduce_4 j token st states stack=reduce 5 6 reduction4 j token st states stack
 and reduce_5 j token st states stack=reduce 6 6 reduction5 j token st states stack
 and reduce_6 j token st states stack=spec3 6 reduction6 j token st states stack
 and reduce_7 j token st states stack=spec3 7 reduction7 j token st states stack
 and reduce_8 j token st states stack=spec1 7 reduction8 j token st states stack
 and reduce_9 j token st states stack=monadReduce 4 8 reduction9 j token st states stack
 and reduce_10 j token st states stack=monadReduce 3 8 reduction10 j token st states stack
 and reduce_11 j token st states stack=spec2 9 reduction11 j token st states stack
 and reduce_12 j token st states stack=spec0 9 reduction12 j token st states stack
 and reduce_13 j token st states stack=spec2 10 reduction13 j token st states stack
 and reduce_14 j token st states stack=spec1 10 reduction14 j token st states stack
 and reduce_15 j token st states stack=spec2 11 reduction15 j token st states stack
 and reduce_16 j token st states stack=spec2 11 reduction16 j token st states stack
 and reduce_17 j token st states stack=spec3 11 reduction17 j token st states stack
 and reduce_18 j token st states stack=spec3 11 reduction18 j token st states stack
 and reduce_19 j token st states stack=spec1 11 reduction19 j token st states stack
 and reduce_20 j token st states stack=spec3 11 reduction20 j token st states stack
 and reduce_21 j token st states stack=spec2 11 reduction21 j token st states stack
 and reduce_22 j token st states stack=spec3 11 reduction22 j token st states stack
 and reduce_23 j token st states stack=reduce 4 11 reduction23 j token st states stack
 and reduce_24 j token st states stack=reduce 5 11 reduction24 j token st states stack
 and reduce_25 j token st states stack=spec2 11 reduction25 j token st states stack
 and reduce_26 j token st states stack=spec2 11 reduction26 j token st states stack
 and reduce_27 j token st states stack=spec2 11 reduction27 j token st states stack
 and reduce_28 j token st states stack=spec2 11 reduction28 j token st states stack
 and reduce_29 j token st states stack=spec2 11 reduction29 j token st states stack
 and reduce_30 j token st states stack=spec2 11 reduction30 j token st states stack
 and reduce_31 j token st states stack=spec3 11 reduction31 j token st states stack
 and reduce_32 j token st states stack=spec1 12 reduction32 j token st states stack
 and reduce_33 j token st states stack=spec0 12 reduction33 j token st states stack
 and reduce_34 j token st states stack=spec2 13 reduction34 j token st states stack
 and reduce_35 j token st states stack=spec1 13 reduction35 j token st states stack
 and reduce_36 j token st states stack=spec2 14 reduction36 j token st states stack
 and reduce_37 j token st states stack=spec2 15 reduction37 j token st states stack
 and reduce_38 j token st states stack=spec0 15 reduction38 j token st states stack
 and reduce_39 j token st states stack=spec1 16 reduction39 j token st states stack
 and reduce_40 j token st states stack=spec0 16 reduction40 j token st states stack
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

end
