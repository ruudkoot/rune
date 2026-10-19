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
 val eof=L.delay(fn()=>(88888,88888,X.Lvar,text"*** Unexpected end of source! ***"))
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
 fun lookup env key fallback=case D.force env of F.Nil=>fallback
   |F.Cons(entry,rest)=>let val(name,value)=D.force entry in if sameText name key then value else lookup rest key fallback end
 fun tokenLine token=let val(line,_,_,_)=L.force token in line end
 fun tokenColumn token=let val(_,column,_,_)=L.force token in column end
 fun pgItem wanted env tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail eof
   |C.Cons(token,rest)=>let val(_,_,tag,value)=L.force token
      in if tag=wanted then POk(env,rest,value)else PFail token end)
 fun pgAlts parsers env tokens=L.delay(fn()=>
   let fun further first second=
         let val l1=tokenLine first val l2=tokenLine second
             val n1=tokenColumn first val n2=tokenColumn second
         in if l2>l1 then second else if l1>l2 then first else if n1>n2 then first else second end
       fun loop [] best=PFail best
         |loop(p::ps)best=case L.force(p env tokens)of PFail next=>loop ps(further next best)|success=>success
   in loop parsers(firstToken tokens)end)
 fun pgThen2 combine p1 p2 env tokens=L.delay(fn()=>case L.force(p1 env tokens)of PFail error=>PFail error
   |POk(e1,t1,a)=>(case L.force(p2 e1 t1)of PFail error=>PFail error
     |POk(e2,t2,b)=>POk(e2,t2,D.delay(fn()=>D.force(combine a b)))))
 fun pgThen3 combine p1 p2 p3 env tokens=L.delay(fn()=>case L.force(p1 env tokens)of PFail error=>PFail error
   |POk(e1,t1,a)=>(case L.force(p2 e1 t1)of PFail error=>PFail error
     |POk(e2,t2,b)=>(case L.force(p3 e2 t2)of PFail error=>PFail error
       |POk(e3,t3,c)=>POk(e3,t3,D.delay(fn()=>D.force(combine a b c))))))
 fun pgThen4 combine p1 p2 p3 p4 env tokens=L.delay(fn()=>case L.force(p1 env tokens)of PFail error=>PFail error
   |POk(e1,t1,a)=>(case L.force(p2 e1 t1)of PFail error=>PFail error
     |POk(e2,t2,b)=>(case L.force(p3 e2 t2)of PFail error=>PFail error
       |POk(e3,t3,c)=>(case L.force(p4 e3 t3)of PFail error=>PFail error
         |POk(e4,t4,d)=>POk(e4,t4,D.delay(fn()=>D.force(combine a b c d)))))))
 fun pgApply convert parser env tokens=L.delay(fn()=>case L.force(parser env tokens)of
      PFail error=>PFail error|POk(e,t,value)=>POk(e,t,D.delay(fn()=>D.force(convert value))))
 fun pgZeroOrMore parser env tokens=L.delay(fn()=>case L.force(parser env tokens)of
      PFail _=>POk(env,tokens,F.empty())
     |POk(e1,t1,value)=>(case L.force(pgZeroOrMore parser e1 t1)of
         PFail _=>POk(e1,t1,one value)
        |POk(e2,t2,values)=>POk(e2,t2,F.cons(value,values))))
 fun pgOneOrMore parser=pgThen2 cons parser(pgZeroOrMore parser)
 fun pgTwoOrMoreWithSep parser sep=
   pgThen4(fn a=>fn _=>fn b=>fn rest=>F.cons(a,F.cons(b,rest)))parser sep parser
      (pgZeroOrMore(pgThen2 select2 sep parser))
 fun pgOneOrMoreWithSep parser sep=pgThen2 cons parser(pgZeroOrMore(pgThen2 select2 sep parser))
 fun pgEmpty value env tokens=L.delay(fn()=>POk(env,tokens,value))
 fun pgZeroOrMoreWithSep parser sep=pgAlts[
      pgOneOrMoreWithSep parser sep,pgApply one parser,pgEmpty(F.empty())]
 fun pgOptional parser env tokens=L.delay(fn()=>case L.force(parser env tokens)of
      PFail _=>POk(env,tokens,D.delay(fn()=>NONE))
     |POk(e,t,value)=>POk(e,t,D.delay(fn()=>SOME value)))
 fun pgGetLineNumber parser env tokens=L.delay(fn()=>
   let val line=D.delay(fn()=>tokenLine(firstToken tokens))
   in case L.force(parser env tokens)of PFail error=>PFail error
      |POk(e,t,value)=>POk(e,t,D.delay(fn()=>(line,value)))end)
 fun pgEatEnd env tokens=L.delay(fn()=>case L.force tokens of C.Nil=>POk(env,tokens,cell())
   |C.Cons(token,rest)=>let val(_,_,tag,_)=L.force token
      in POk(env,if tag=X.Lsemi orelse tag=X.Lrbrace then rest else tokens,cell())end)
 fun pgDeclList parser=pgThen3(fn _=>fn values=>fn _=>values)
   (pgItem X.Llbrace)(pgOneOrMoreWithSep parser(pgItem X.Lsemi))pgEatEnd

end
