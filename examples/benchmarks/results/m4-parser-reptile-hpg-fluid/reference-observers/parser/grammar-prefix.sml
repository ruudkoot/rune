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
