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

end
structure H=BenchHappyFn(BenchNeed)
