functor BenchNofibParserFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure X=BenchNofibParserLexFn(D)
 structure F=X.F
 structure C=X.C
 type text=X.text
 val text=X.text
 val string=X.string
 type ids=char F.node F.seq
 datatype fixity=InfixL|InfixR|InfixN
 type environment=(text*(fixity D.t*int D.t)D.t)F.seq
 datatype moduleNode=MkModule of text*topDeclNode F.seq
 and fixityDeclNode=MkFixDecl of text*(fixity D.t*int D.t)D.t
 and dataDeclNode=MkDataDecl of text*(ids*(text*typeExprNode F.seq)F.seq)D.t
 and topDeclNode=MkTopF of fixityDecl|MkTopD of dataDecl|MkTopV of valBind
 and typeExprNode=TypeVar of text|TypeArr of typeExpr*typeExpr|TypeCon of text*typeExprNode F.seq
   |TypeList of typeExpr|TypeTuple of typeExprNode F.seq
 and valBindNode=MkValBind of int D.t*lhs*expr
 and lhsNode=LhsPat of pat|LhsVar of text*patNode F.seq
 and patNode=PatVar of text|PatCon of text*patNode F.seq|PatWild|PatList of patNode F.seq|PatTuple of patNode F.seq
 and exprNode=ExprVar of text|ExprCon of text|ExprApp of expr*expr|ExprLam of patNode F.seq*expr
   |ExprCase of expr*caseAltNode F.seq|ExprLetrec of valBindNode F.seq*expr|ExprWhere of expr*valBindNode F.seq
   |ExprGuards of(expr*expr)F.seq|ExprLiteral of literal|ExprList of exprNode F.seq
   |ExprTuple of exprNode F.seq|ExprIf of expr*expr*expr|ExprBar|ExprFail
 and caseAltNode=MkExprCaseAlt of pat*expr
 and literalNode=LiteralInt of int D.t|LiteralChar of char D.t|LiteralString of text
 withtype module=moduleNode D.t
 and fixityDecl=fixityDeclNode D.t
 and dataDecl=dataDeclNode D.t
 and typeExpr=typeExprNode D.t
 and valBind=valBindNode D.t
 and lhs=lhsNode D.t
 and pat=patNode D.t
 and expr=exprNode D.t
 and literal=literalNode D.t
 type entry=bool D.t*expr*text
 datatype 'a resultNode=POk of environment*X.tokens*'a D.t|PFail of X.token L.delay
 type 'a result='a resultNode L.delay
 type 'a parser=environment->X.tokens->'a result
 val eof=L.delay(fn()=>(L.delay(fn()=>88888),L.delay(fn()=>88888),X.Lvar,text"*** Unexpected end of source! ***"))
 fun firstToken tokens=case L.force tokens of C.Nil=>eof|C.Cons(value,_)=>value
 fun cell value=D.delay(fn()=>value)
 fun one value=F.cons(value,F.empty())
 fun fst3 value=let val(a,_,_)=D.force value in a end
 fun snd3 value=let val(_,a,_)=D.force value in a end
 fun thd3 value=let val(_,_,a)=D.force value in a end
 fun pair a b=D.delay(fn()=>(a,b))
 fun select1 a _=a
 fun select2 _ b=b
 fun cons a b=F.cons(a,b)
 fun sameText a b=case(D.force a,D.force b)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xs),F.Cons(y,ys))=>D.force x=D.force y andalso sameText xs ys|_=>false
 fun lookup env key fallback=
   let fun matching values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(entry,rest)=>let val(name,value)=D.force entry
           in if sameText name key then F.cons(value,matching rest)else matching rest end)
       val choices=F.append(matching env)(one fallback)
   in case D.force choices of F.Cons(value,_)=>value|F.Nil=>raise Fail"lookup invariant"end
 fun tokenLine token=let val(line,_,_,_)=L.force token in L.force line end
 fun tokenColumn token=let val(_,column,_,_)=L.force token in L.force column end
