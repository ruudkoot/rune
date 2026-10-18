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
