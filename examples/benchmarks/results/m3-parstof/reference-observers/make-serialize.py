from pathlib import Path
import json,re
p=Path(__file__).resolve().parent
ctors=json.loads((p/'ast-constructors.json').read_text())
source=(p/'source/Main.hs').read_text()
defs=re.findall(r'data\n\s+(T_pt\w+)=([^;]+);',source)
t=r'''
 fun quote text="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"|c=>String.str c)text^"\""
 fun arr xs="["^String.concatWith","xs^"]"
 fun textJSON cell=quote(String.implode(D.force cell))
 fun intJSON cell=intText(D.force cell)
 fun charJSON cell=intText(Char.ord(D.force cell))
'''
for index,(name,body)in enumerate(defs):
 cases=[]
 for part in body.split('|'):
  ctor,*fields=part.split();args=['a'+str(i)for i in range(len(fields))]
  pattern=ctor+('('+','.join(args)+')'if fields else'')
  items=['quote"'+ctor+'"']
  for typ,arg in zip(fields,args):
   f={'T_string':'textJSON','Int':'intJSON','Char':'charJSON'}.get(typ,'dump_'+typ)
   items.append(f+' '+arg)
  cases.append(pattern+'=>arr['+','.join(items)+']')
 t+=(' fun 'if index==0 else' and ')+'dump_'+name+' cell=case D.force cell of '+'|'.join(cases)+'\n'
lex=(p/'lex-pilot.sml').read_text()
a=lex.index(' fun value ');b=lex.index(' fun read ',a)
lex=lex[a:b].replace('fun value','fun value').replace('n(Char.ord','intText(Char.ord').replace('n(D.force','intText(D.force').replace('n tag','intText tag').replace('n line','intText line').replace('fun tokens stream','fun dumpTokens stream').replace(',tokens tail',',dumpTokens tail')
t+=lex
t+=r'''
 fun parseJSON input=case c_par_proglist(X.tokenize input)of
    ParseFail Unknown=>arr[quote"F_Par_fail",arr[quote"C_Emess_uk"]]
   |ParseFail(Known(message,line))=>arr[quote"F_Par_fail",arr[quote"F_Emess_known",quote(L.force message),intText line]]
   |Success(tree,rest)=>arr[quote"F_Par_succ",dump_T_ptproglist tree,dumpTokens rest]
'''
(p/'serialize-body.sml').write_text(t)
s=(p/'kernel.sml').read_text();assert s.endswith('end\n')
(p/'kernel-observe.sml').write_text(s[:-4]+t+'end\n')
(p/'pilot.sml').write_text(r'''
functor ParstofPilotFn(D:BENCH_SUSPEND)=struct
 structure K=BenchParstofFn(D)
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name=let val actual=K.parseJSON(read(name^".input"))^"\n"
       val expected=read(name^"-parse.reference")
   in if actual=expected then print("PASS "^name^"\n")else
     let val f=TextIO.openOut(name^"-parse-actual.json")
     in TextIO.output(f,actual);TextIO.closeOut f;raise Fail name end end
 val _=List.app check["default","identity","application","types","conditional","let-case","lexemes","bad","empty","unterminated-comment"]
end
structure N=ParstofPilotFn(BenchNeed)
structure E=ParstofPilotFn(BenchStrict)
''')
