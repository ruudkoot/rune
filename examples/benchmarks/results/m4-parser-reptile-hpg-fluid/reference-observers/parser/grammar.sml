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
