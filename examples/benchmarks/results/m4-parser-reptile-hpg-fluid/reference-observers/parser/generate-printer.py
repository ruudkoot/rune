from pathlib import Path
p=Path(__file__).resolve().parent
b=Path('tests/out/benchmarks/nofib-happy-originals/codegen-builders.sml').read_text().split(' (* The original routine')[0]
out=' val emptyText=text""\n'+b
out+=r'''
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
'''
schema=[
 ('showModule',[('MkModule',['showText a','showList showTop b'])]),
 ('showFixDecl',[('MkFixDecl',['showText a','showPriority b'])]),
 ('showDataDecl',[('MkDataDecl',['showText a','showDataParameters b'])]),
 ('showTop',[('MkTopF',['showFixDecl 11 a']),('MkTopD',['showDataDecl 11 a']),('MkTopV',['showValBind 11 a'])]),
 ('showType',[('TypeVar',['showText a']),('TypeArr',['showType 11 a','showType 11 b']),('TypeCon',['showText a','showList showType b']),('TypeList',['showType 11 a']),('TypeTuple',['showList showType a'])]),
 ('showValBind',[('MkValBind',['showInt 11 a','showLhs 11 b','showExpr 11 c'])]),
 ('showLhs',[('LhsPat',['showPat 11 a']),('LhsVar',['showText a','showList showPat b'])]),
 ('showPat',[('PatVar',['showText a']),('PatCon',['showText a','showList showPat b']),('PatWild',[]),('PatList',['showList showPat a']),('PatTuple',['showList showPat a'])]),
 ('showExpr',[('ExprVar',['showText a']),('ExprCon',['showText a']),('ExprApp',['showExpr 11 a','showExpr 11 b']),('ExprLam',['showList showPat a','showExpr 11 b']),('ExprCase',['showExpr 11 a','showList showCaseAlt b']),('ExprLetrec',['showList showValBind a','showExpr 11 b']),('ExprWhere',['showExpr 11 a','showList showValBind b']),('ExprGuards',['showList (fn _=>showGuard) a']),('ExprLiteral',['showLiteral 11 a']),('ExprList',['showList showExpr a']),('ExprTuple',['showList showExpr a']),('ExprIf',['showExpr 11 a','showExpr 11 b','showExpr 11 c']),('ExprBar',[]),('ExprFail',[])]),
 ('showCaseAlt',[('MkExprCaseAlt',['showPat 11 a','showExpr 11 b'])]),
 ('showLiteral',[('LiteralInt',['showInt 11 a']),('LiteralChar',['showChar a']),('LiteralString',['showText a'])])]
for i,(function,ctors)in enumerate(schema):
 out+=(' fun 'if i==0 else' and ')+function+' d value=B.delayed(fn()=>case D.force value of\n'
 for j,(ctor,fields)in enumerate(ctors):
  args=['a','b','c'][:len(fields)]
  pattern=ctor+('('+','.join(args)+')'if args else'')
  out+=('     'if j==0 else'    |')+pattern+'=>constructor d "'+ctor+'"['+','.join(fields)+']\n'
 out+='   )\n'
out+=r'''
 and showGuard value=B.delayed(fn()=>let val(a,b)=D.force value in showTuple[showExpr 0 a,showExpr 0 b]end)
 and showConAlt value=B.delayed(fn()=>let val(name,args)=D.force value in showTuple[showText name,showList showType args]end)
 and showDataParameters value=B.delayed(fn()=>let val(parameters,constructors)=D.force value
   in showTuple[showStrings parameters,showList(fn _=>showConAlt)constructors]end)
 fun showTag tag=B.literal(case tag of TAGS)
 fun showToken token=B.delayed(fn()=>let val(line,column,tag,value)=L.force token
   in showTuple[B.delayed(fn()=>B.literal(signed(L.force line))),
     B.delayed(fn()=>B.literal(signed(L.force column))),showTag tag,showText value]end)
 fun report result=B.output(B.delayed(fn()=>case L.force result of
    PFail token=>B.pieces[B.literal"\n\nFailed on token: ",showToken token,B.literal"\n\n"]
   |POk(env,tokens,value)=>B.pieces[B.literal"\n\nSucceeded, with:\n   Size env = ",
      B.literal(Int.toString(F.length env)),B.literal"\n   Next token = ",showToken(firstToken tokens),
      B.literal"\n\n   Result = ",showModule 0 value,B.literal"\n\n"]))
 fun parse input=parserTest(X.main input)
'''
import re
tags=re.search(r' datatype lex=([^\n]+)',(p/'lexer-prefix.sml').read_text())[1].split('|')
out=out.replace('TAGS','|'.join('X.'+n+'=>'+repr(n).replace("'",'"')for n in tags))
(p/'printer.sml').write_text(out)
(p/'parser-kernel.sml').write_text(''.join((p/n).read_text()for n in ['types.sml','combinators.sml','grammar-prefix.sml','grammar.sml','precedence.sml','printer.sml'])+'\nend\n')
print('complete derived-Show builder printer generated')
