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
