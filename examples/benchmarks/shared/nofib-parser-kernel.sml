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
 fun pgItem wanted env tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail eof
   |C.Cons(token,rest)=>let val(_,_,tag,value)=L.force token
      in if tag=wanted then POk(env,rest,value)else PFail token end)
 fun pgAlts parsers env tokens=L.delay(fn()=>
   let fun further first second=
         let val l1=tokenLine first val l2=tokenLine second
         in if l2>l1 then second else if l1>l2 then first
            else let val n1=tokenColumn first val n2=tokenColumn second
                 in if n1>n2 then first else second end end
       fun loop [] best=PFail best
         |loop(p::ps)best=case L.force(p env tokens)of PFail next=>loop ps(further next best)|success=>success
   in loop parsers(L.delay(fn()=>L.force(firstToken tokens)))end)
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
   case L.force(parser env tokens)of PFail error=>PFail error
    |POk(e,t,value)=>POk(e,t,D.delay(fn()=>(D.delay(fn()=>tokenLine(firstToken tokens)),value))))
 fun pgEatEnd env tokens=L.delay(fn()=>case L.force tokens of C.Nil=>POk(env,tokens,cell())
   |C.Cons(token,rest)=>let val(_,_,tag,_)=L.force token
      in POk(env,if tag=X.Lsemi orelse tag=X.Lrbrace then rest else tokens,cell())end)
 fun pgDeclList parser=pgThen3(fn _=>fn values=>fn _=>values)
   (pgItem X.Llbrace)(pgOneOrMoreWithSep parser(pgItem X.Lsemi))pgEatEnd
 fun node1 ctor a=D.delay(fn()=>ctor a)
 fun node2 ctor a b=D.delay(fn()=>ctor(a,b))
 fun node3 ctor a b c=D.delay(fn()=>ctor(a,b,c))
 val minusExpr=node1 ExprVar(text"-")
 val zeroExpr=node1 ExprLiteral(node1 LiteralInt(cell 0))
 fun makeWhere expression clauses=D.delay(fn()=>case D.force clauses of NONE=>D.force expression|SOME defs=>ExprWhere(expression,defs))
 val cache_paLiteral:(literalNode parser)option ref=ref NONE
 val cache_paExpr:(exprNode parser)option ref=ref NONE
 val cache_paUnaryMinusExpr:(exprNode parser)option ref=ref NONE
 val cache_paCaseExpr:(exprNode parser)option ref=ref NONE
 val cache_paAlt:(caseAltNode parser)option ref=ref NONE
 val cache_paGalt:((expr*expr) parser)option ref=ref NONE
 val cache_paLamExpr:(exprNode parser)option ref=ref NONE
 val cache_paLetExpr:(exprNode parser)option ref=ref NONE
 val cache_paValdefs:(valBindNode F.node parser)option ref=ref NONE
 val cache_paLhs:(lhsNode parser)option ref=ref NONE
 val cache_paValdef:(valBindNode parser)option ref=ref NONE
 val cache_paWhereClause:(valBindNode F.node parser)option ref=ref NONE
 val cache_paGrhs:((expr*expr) parser)option ref=ref NONE
 val cache_paAPat:(patNode parser)option ref=ref NONE
 val cache_paPat:(patNode parser)option ref=ref NONE
 val cache_paIfExpr:(exprNode parser)option ref=ref NONE
 val cache_paAExpr:(entry parser)option ref=ref NONE
 val cache_paListExpr:(exprNode F.node parser)option ref=ref NONE
 val cache_paTupleExpr:(exprNode F.node parser)option ref=ref NONE
 val cache_paOp:(entry parser)option ref=ref NONE
 val cache_paDataDecl:(dataDeclNode parser)option ref=ref NONE
 val cache_paDataDecl_main:(dataDeclNode parser)option ref=ref NONE
 val cache_paConstrs:((text*typeExprNode F.seq) parser)option ref=ref NONE
 val cache_paType:(typeExprNode parser)option ref=ref NONE
 val cache_paAType:(typeExprNode parser)option ref=ref NONE
 val cache_paInfixWord:(fixity parser)option ref=ref NONE
 val cache_paTopDecl:(topDeclNode parser)option ref=ref NONE
 val cache_paModule:(moduleNode parser)option ref=ref NONE
 val cache_hsAExprOrOp:(entry parser)option ref=ref NONE
 fun cached slot build env tokens=
   let val parser=case !slot of SOME value=>value|NONE=>let val value=build()in slot:=SOME value;value end
   in parser env tokens end
 val paVar:char F.node parser=pgItem X.Lvar
 val paCon:char F.node parser=pgItem X.Lcon
 val paVarop:char F.node parser=pgItem X.Lvarop
 val paConop:char F.node parser=pgItem X.Lconop
 val paMinus:char F.node parser=pgItem X.Lminus
 val defaultFixity=pair(cell InfixL)(cell 9)
 fun paLiteral env tokens=cached cache_paLiteral(fn()=>pgAlts[
      pgApply(fn chars=>node1 LiteralInt(D.delay(fn()=>X.integer(F.toList chars))))(pgItem X.Lintlit),
      pgApply(fn chars=>node1 LiteralChar(D.delay(fn()=>F.nth chars 0)))(pgItem X.Lcharlit),
      pgApply(node1 LiteralString)(pgItem X.Lstringlit)])env tokens
 and paExpr env tokens=cached cache_paExpr(fn()=>pgAlts[
      paCaseExpr,paLetExpr,paLamExpr,paIfExpr,paUnaryMinusExpr,hsDoExpr[]])env tokens
 and paUnaryMinusExpr env tokens=cached cache_paUnaryMinusExpr(fn()=>
      pgThen2(fn _=>fn entry=>node2 ExprApp(node2 ExprApp minusExpr zeroExpr)(snd3 entry))paMinus paAExpr)env tokens
 and paCaseExpr env tokens=cached cache_paCaseExpr(fn()=>
      pgThen4(fn _=>fn expression=>fn _=>fn alts=>node2 ExprCase expression alts)
        (pgItem X.Lcase)paExpr(pgItem X.Lof)(pgDeclList paAlt))env tokens
 and paAlt env tokens=cached cache_paAlt(fn()=>pgAlts[
      pgThen4(fn pattern=>fn _=>fn expression=>fn wheres=>node2 MkExprCaseAlt pattern(makeWhere expression wheres))
        paPat(pgItem X.Larrow)paExpr(pgOptional paWhereClause),
      pgThen3(fn pattern=>fn guards=>fn wheres=>node2 MkExprCaseAlt pattern(makeWhere(node1 ExprGuards guards)wheres))
        paPat(pgOneOrMore paGalt)(pgOptional paWhereClause)])env tokens
 and paGalt env tokens=cached cache_paGalt(fn()=>
      pgThen4(fn _=>fn guard=>fn _=>fn expression=>pair guard expression)
        (pgItem X.Lbar)paExpr(pgItem X.Larrow)paExpr)env tokens
 and paLamExpr env tokens=cached cache_paLamExpr(fn()=>
      pgThen4(fn _=>fn patterns=>fn _=>fn expression=>node2 ExprLam patterns expression)
        (pgItem X.Lslash)(pgZeroOrMore paAPat)(pgItem X.Larrow)paExpr)env tokens
 and paLetExpr env tokens=cached cache_paLetExpr(fn()=>
      pgThen4(fn _=>fn decls=>fn _=>fn expression=>node2 ExprLetrec decls expression)
        (pgItem X.Llet)paValdefs(pgItem X.Lin)paExpr)env tokens
 and paValdefs env tokens=cached cache_paValdefs(fn()=>pgApply(fn value=>value)(pgDeclList paValdef))env tokens
 and paLhs env tokens=cached cache_paLhs(fn()=>pgAlts[
      pgThen2(node2 LhsVar)paVar(pgOneOrMore paPat),pgApply(node1 LhsPat)paPat])env tokens
 and paValdef env tokens=cached cache_paValdef(fn()=>pgAlts[
      pgThen4(fn numbered=>fn _=>fn rhs=>fn wheres=>D.delay(fn()=>
         let val(line,left)=D.force numbered in MkValBind(line,left,makeWhere rhs wheres)end))
        (pgGetLineNumber paLhs)(pgItem X.Lequals)paExpr(pgOptional paWhereClause),
      pgThen3(fn numbered=>fn guards=>fn wheres=>D.delay(fn()=>
         let val(line,left)=D.force numbered in MkValBind(line,left,makeWhere(node1 ExprGuards guards)wheres)end))
        (pgGetLineNumber paLhs)(pgOneOrMore paGrhs)(pgOptional paWhereClause)])env tokens
 and paWhereClause env tokens=cached cache_paWhereClause(fn()=>pgThen2 select2(pgItem X.Lwhere)paValdefs)env tokens
 and paGrhs env tokens=cached cache_paGrhs(fn()=>
      pgThen4(fn _=>fn guard=>fn _=>fn expression=>pair guard expression)
        (pgItem X.Lbar)paExpr(pgItem X.Lequals)paExpr)env tokens
 and paAPat env tokens=cached cache_paAPat(fn()=>pgAlts[
      pgApply(node1 PatVar)paVar,
      pgApply(fn name=>node2 PatCon name(F.empty()))paCon,
      pgApply(fn _=>D.delay(fn()=>PatWild))(pgItem X.Lunder),
      pgApply(node1 PatTuple)(pgThen3(fn _=>fn values=>fn _=>values)
        (pgItem X.Llparen)(pgTwoOrMoreWithSep paPat(pgItem X.Lcomma))(pgItem X.Lrparen)),
      pgApply(node1 PatList)(pgThen3(fn _=>fn values=>fn _=>values)
        (pgItem X.Llbrack)(pgZeroOrMoreWithSep paPat(pgItem X.Lcomma))(pgItem X.Lrbrack)),
      pgThen3(fn _=>fn pattern=>fn _=>pattern)(pgItem X.Llparen)paPat(pgItem X.Lrparen)])env tokens
 and paPat env tokens=cached cache_paPat(fn()=>pgAlts[
      pgThen2(node2 PatCon)paCon(pgOneOrMore paAPat),
      pgThen3(fn left=>fn name=>fn right=>node2 PatCon name(F.cons(left,one right)))paAPat paConop paPat,
      paAPat])env tokens
 and paIfExpr env tokens=cached cache_paIfExpr(fn()=>
      pgThen4(fn _=>fn condition=>fn _=>fn branches=>D.delay(fn()=>
        let val(yes,no)=D.force branches in ExprIf(condition,yes,no)end))
        (pgItem X.Lif)paExpr(pgItem X.Lthen)
        (pgThen3(fn yes=>fn _=>fn no=>pair yes no)paExpr(pgItem X.Lelse)paExpr))env tokens
 and paAExpr env tokens=cached cache_paAExpr(fn()=>
      pgApply(fn expression=>D.delay(fn()=>(cell false,expression,text"")))
       (pgAlts[pgApply(node1 ExprVar)paVar,pgApply(node1 ExprCon)paCon,
         pgApply(node1 ExprLiteral)paLiteral,pgApply(node1 ExprList)paListExpr,
         pgApply(node1 ExprTuple)paTupleExpr,
         pgThen3(fn _=>fn expression=>fn _=>expression)(pgItem X.Llparen)paExpr(pgItem X.Lrparen)]))env tokens
 and paListExpr env tokens=cached cache_paListExpr(fn()=>
      pgThen3(fn _=>fn values=>fn _=>values)(pgItem X.Llbrack)
        (pgZeroOrMoreWithSep paExpr(pgItem X.Lcomma))(pgItem X.Lrbrack))env tokens
 and paTupleExpr env tokens=cached cache_paTupleExpr(fn()=>
      pgThen3(fn _=>fn values=>fn _=>values)(pgItem X.Llparen)
        (pgTwoOrMoreWithSep paExpr(pgItem X.Lcomma))(pgItem X.Lrparen))env tokens
 and paOp env tokens=cached cache_paOp(fn()=>pgAlts[
      pgApply(fn name=>D.delay(fn()=>(cell true,node1 ExprVar name,name)))paVarop,
      pgApply(fn name=>D.delay(fn()=>(cell true,node1 ExprCon name,name)))paConop,
      pgApply(fn name=>D.delay(fn()=>(cell true,node1 ExprVar name,name)))paMinus])env tokens
 and paDataDecl env tokens=cached cache_paDataDecl(fn()=>
      pgThen2 select2(pgItem X.Ldata)paDataDecl_main)env tokens
 and paDataDecl_main env tokens=cached cache_paDataDecl_main(fn()=>
      pgThen4(fn name=>fn parameters=>fn _=>fn constructors=>
        node2 MkDataDecl name(D.delay(fn()=>(parameters,constructors))))
        paCon(pgZeroOrMore paVar)(pgItem X.Lequals)(pgOneOrMoreWithSep paConstrs(pgItem X.Lbar)))env tokens
 and paConstrs env tokens=cached cache_paConstrs(fn()=>pgThen2 pair paCon(pgZeroOrMore paAType))env tokens
 and paType env tokens=cached cache_paType(fn()=>pgAlts[
      pgThen3(fn first=>fn _=>fn rest=>node2 TypeArr first rest)paAType(pgItem X.Larrow)paType,
      pgThen2(node2 TypeCon)paCon(pgOneOrMore paAType),paAType])env tokens
 and paAType env tokens=cached cache_paAType(fn()=>pgAlts[
      pgApply(node1 TypeVar)paVar,pgApply(fn name=>node2 TypeCon name(F.empty()))paCon,
      pgThen3(fn _=>fn value=>fn _=>value)(pgItem X.Llparen)paType(pgItem X.Lrparen),
      pgThen3(fn _=>fn value=>fn _=>node1 TypeList value)(pgItem X.Llbrack)paType(pgItem X.Lrbrack),
      pgThen3(fn _=>fn values=>fn _=>node1 TypeTuple values)(pgItem X.Llparen)
        (pgTwoOrMoreWithSep paType(pgItem X.Lcomma))(pgItem X.Lrparen)])env tokens
 and paInfixDecl env tokens=L.delay(fn()=>
      let fun dump value=D.delay(fn()=>case D.force value of ExprVar name=>D.force name
             |ExprCon name=>D.force name|_=>raise Match)
          val parsed=pgThen3(fn assoc=>fn priority=>fn name=>node2 MkFixDecl name(D.delay(fn()=>(assoc,priority))))
             paInfixWord(pgApply(fn chars=>D.delay(fn()=>X.integer(F.toList chars)))(pgItem X.Lintlit))
             (pgApply(fn entry=>dump(snd3 entry))paOp)env tokens
      in case L.force parsed of PFail error=>PFail error
        |POk(e,t,value)=>let val MkFixDecl(name,priority)=D.force value
            val next=F.cons(D.delay(fn()=>(name,priority)),e)
          in POk(next,t,node2 MkFixDecl name priority)end end)
 and paInfixWord env tokens=cached cache_paInfixWord(fn()=>pgAlts[
      pgApply(fn _=>cell InfixL)(pgItem X.Linfixl),pgApply(fn _=>cell InfixR)(pgItem X.Linfixr),
      pgApply(fn _=>cell InfixN)(pgItem X.Linfix)])env tokens
 and paTopDecl env tokens=cached cache_paTopDecl(fn()=>pgAlts[
      pgApply(node1 MkTopF)paInfixDecl,pgApply(node1 MkTopD)paDataDecl,pgApply(node1 MkTopV)paValdef])env tokens
 and paModule env tokens=cached cache_paModule(fn()=>
      pgThen4(fn _=>fn name=>fn _=>fn declarations=>node2 MkModule name declarations)
        (pgItem X.Lmodule)paCon(pgItem X.Lwhere)(pgDeclList paTopDecl))env tokens
 and hsAExprOrOp env tokens=cached cache_hsAExprOrOp(fn()=>pgAlts[paAExpr,paOp])env tokens
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
 val emptyText=text""
 (* ProduceCode/GenUtils ShowS builders, retaining character spines and
  * delayed right operands rather than flattening intermediate output. *)
 structure B=
 struct
   type builder=text->text
   fun id tail=tail
   fun str value tail=F.append value tail
   fun literal value=str(X.text value)
   fun cat left right tail=left(F.defer(fn()=>right tail))
   fun delayed body tail=F.defer(fn()=>body()tail)
   fun many builders tail=F.defer(fn()=>case D.force builders of F.Nil=>tail
     |F.Cons(value,rest)=>D.force value(F.defer(fn()=>many rest tail)))
   fun pieces values=many(F.fromList values)
   fun interleave separator builders tail=F.defer(fn()=>case D.force builders of F.Nil=>tail
     |F.Cons(value,rest)=>D.force value(F.append(X.text separator)(F.defer(fn()=>interleave separator rest tail))))
   fun interleave1 separator builders tail=F.defer(fn()=>case D.force builders of F.Nil=>raise Empty
     |F.Cons(value,rest)=>D.force value(F.defer(fn()=>case D.force rest of F.Nil=>tail
       |_=>F.append(X.text separator)(interleave1 separator rest tail))))
   fun bracket value=pieces[literal"(",value,literal")"]
   fun integer n=delayed(fn()=>literal(Int.toString n))
   fun output builder=builder emptyText
 end

 fun signed n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun showInt d value=B.delayed(fn()=>
   let val n=D.force value val literal=B.literal(signed n)
   in if n<0 andalso d>6 then B.bracket literal else literal end)
 fun showText value=B.delayed(fn()=>B.literal(X.H.showString(List.map Char.ord(F.toList value))))
 fun showChar value=B.delayed(fn()=>B.literal(X.H.showCharacter[Char.ord(D.force value)]))
 fun showList printer values=B.delayed(fn()=>
   let fun builders values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
         |F.Cons(value,rest)=>F.cons(D.delay(fn()=>printer 0 value),builders rest))
       val fields=builders values
   in B.pieces[B.literal"[",B.delayed(fn()=>case D.force fields of F.Nil=>B.id|_=>B.interleave1","fields),B.literal"]"]end)
 fun showStrings values=showList(fn _=>showText)values
 fun showTuple fields=B.pieces[B.literal"(",B.interleave1","(F.fromList fields),B.literal")"]
 fun constructor d name fields=
   let val body=B.pieces[B.literal name,B.many(F.fromList(List.map(fn field=>B.pieces[B.literal" ",field])fields))]
   in if not(List.null fields)andalso d>10 then B.bracket body else body end
 fun showFixity value=B.delayed(fn()=>B.literal(case D.force value of InfixL=>"InfixL"|InfixR=>"InfixR"|InfixN=>"InfixN"))
 fun showPriority value=B.delayed(fn()=>let val(assoc,priority)=D.force value
   in showTuple[showFixity assoc,showInt 0 priority]end)
 fun showModule d value=B.delayed(fn()=>case D.force value of
     MkModule(a,b)=>constructor d "MkModule"[showText a,showList showTop b]
   )
 and showFixDecl d value=B.delayed(fn()=>case D.force value of
     MkFixDecl(a,b)=>constructor d "MkFixDecl"[showText a,showPriority b]
   )
 and showDataDecl d value=B.delayed(fn()=>case D.force value of
     MkDataDecl(a,b)=>constructor d "MkDataDecl"[showText a,showDataParameters b]
   )
 and showTop d value=B.delayed(fn()=>case D.force value of
     MkTopF(a)=>constructor d "MkTopF"[showFixDecl 11 a]
    |MkTopD(a)=>constructor d "MkTopD"[showDataDecl 11 a]
    |MkTopV(a)=>constructor d "MkTopV"[showValBind 11 a]
   )
 and showType d value=B.delayed(fn()=>case D.force value of
     TypeVar(a)=>constructor d "TypeVar"[showText a]
    |TypeArr(a,b)=>constructor d "TypeArr"[showType 11 a,showType 11 b]
    |TypeCon(a,b)=>constructor d "TypeCon"[showText a,showList showType b]
    |TypeList(a)=>constructor d "TypeList"[showType 11 a]
    |TypeTuple(a)=>constructor d "TypeTuple"[showList showType a]
   )
 and showValBind d value=B.delayed(fn()=>case D.force value of
     MkValBind(a,b,c)=>constructor d "MkValBind"[showInt 11 a,showLhs 11 b,showExpr 11 c]
   )
 and showLhs d value=B.delayed(fn()=>case D.force value of
     LhsPat(a)=>constructor d "LhsPat"[showPat 11 a]
    |LhsVar(a,b)=>constructor d "LhsVar"[showText a,showList showPat b]
   )
 and showPat d value=B.delayed(fn()=>case D.force value of
     PatVar(a)=>constructor d "PatVar"[showText a]
    |PatCon(a,b)=>constructor d "PatCon"[showText a,showList showPat b]
    |PatWild=>constructor d "PatWild"[]
    |PatList(a)=>constructor d "PatList"[showList showPat a]
    |PatTuple(a)=>constructor d "PatTuple"[showList showPat a]
   )
 and showExpr d value=B.delayed(fn()=>case D.force value of
     ExprVar(a)=>constructor d "ExprVar"[showText a]
    |ExprCon(a)=>constructor d "ExprCon"[showText a]
    |ExprApp(a,b)=>constructor d "ExprApp"[showExpr 11 a,showExpr 11 b]
    |ExprLam(a,b)=>constructor d "ExprLam"[showList showPat a,showExpr 11 b]
    |ExprCase(a,b)=>constructor d "ExprCase"[showExpr 11 a,showList showCaseAlt b]
    |ExprLetrec(a,b)=>constructor d "ExprLetrec"[showList showValBind a,showExpr 11 b]
    |ExprWhere(a,b)=>constructor d "ExprWhere"[showExpr 11 a,showList showValBind b]
    |ExprGuards(a)=>constructor d "ExprGuards"[showList (fn _=>showGuard) a]
    |ExprLiteral(a)=>constructor d "ExprLiteral"[showLiteral 11 a]
    |ExprList(a)=>constructor d "ExprList"[showList showExpr a]
    |ExprTuple(a)=>constructor d "ExprTuple"[showList showExpr a]
    |ExprIf(a,b,c)=>constructor d "ExprIf"[showExpr 11 a,showExpr 11 b,showExpr 11 c]
    |ExprBar=>constructor d "ExprBar"[]
    |ExprFail=>constructor d "ExprFail"[]
   )
 and showCaseAlt d value=B.delayed(fn()=>case D.force value of
     MkExprCaseAlt(a,b)=>constructor d "MkExprCaseAlt"[showPat 11 a,showExpr 11 b]
   )
 and showLiteral d value=B.delayed(fn()=>case D.force value of
     LiteralInt(a)=>constructor d "LiteralInt"[showInt 11 a]
    |LiteralChar(a)=>constructor d "LiteralChar"[showChar a]
    |LiteralString(a)=>constructor d "LiteralString"[showText a]
   )

 and showGuard value=B.delayed(fn()=>let val(a,b)=D.force value in showTuple[showExpr 0 a,showExpr 0 b]end)
 and showConAlt value=B.delayed(fn()=>let val(name,args)=D.force value in showTuple[showText name,showList showType args]end)
 and showDataParameters value=B.delayed(fn()=>let val(parameters,constructors)=D.force value
   in showTuple[showStrings parameters,showList(fn _=>showConAlt)constructors]end)
 fun showTag tag=B.literal(case tag of X.Lcon=>"Lcon"|X.Lconop=>"Lconop"|X.Lvar=>"Lvar"|X.Lvarop=>"Lvarop"|X.Lintlit=>"Lintlit"|X.Lcharlit=>"Lcharlit"|X.Lstringlit=>"Lstringlit"|X.Llbrace=>"Llbrace"|X.Lrbrace=>"Lrbrace"|X.Lsemi=>"Lsemi"|X.Lequals=>"Lequals"|X.Lbar=>"Lbar"|X.Larrow=>"Larrow"|X.Llparen=>"Llparen"|X.Lrparen=>"Lrparen"|X.Lcomma=>"Lcomma"|X.Llbrack=>"Llbrack"|X.Lrbrack=>"Lrbrack"|X.Lunder=>"Lunder"|X.Lminus=>"Lminus"|X.Lslash=>"Lslash"|X.Lmodule=>"Lmodule"|X.Linfixl=>"Linfixl"|X.Linfixr=>"Linfixr"|X.Linfix=>"Linfix"|X.Lext=>"Lext"|X.Ldata=>"Ldata"|X.Lif=>"Lif"|X.Lthen=>"Lthen"|X.Lelse=>"Lelse"|X.Llet=>"Llet"|X.Lin=>"Lin"|X.Lcase=>"Lcase"|X.Lof=>"Lof"|X.Lwhere=>"Lwhere"|X.Leof=>"Leof")
 fun showToken token=B.delayed(fn()=>let val(line,column,tag,value)=L.force token
   in showTuple[B.delayed(fn()=>B.literal(signed(L.force line))),
     B.delayed(fn()=>B.literal(signed(L.force column))),showTag tag,showText value]end)
 fun report result=B.output(B.delayed(fn()=>case L.force result of
    PFail token=>B.pieces[B.literal"\n\nFailed on token: ",showToken token,B.literal"\n\n"]
   |POk(env,tokens,value)=>B.pieces[B.literal"\n\nSucceeded, with:\n   Size env = ",
      B.literal(Int.toString(F.length env)),B.literal"\n   Next token = ",showToken(firstToken tokens),
      B.literal"\n\n   Result = ",showModule 0 value,B.literal"\n\n"]))
 fun parse input=parserTest(X.main input)
 structure W=Word64
 fun hash chars=
   let fun loop value chars=case D.force chars of F.Nil=>value
         |F.Cons(c,rest)=>loop(W.+(W.fromInt(Char.ord(D.force c)),W.*(value,0w31)))rest
   in loop 0w0 chars end
 fun signedHash word=
   let val n=W.toLargeInt word
       val value=if W.andb(word,0wx8000000000000000)=0w0 then n else n-18446744073709551616
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)end
 fun benchmark input=hash(report(parse input))

 type input=X.input
 val input=X.input

end
