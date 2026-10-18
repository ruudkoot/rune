from pathlib import Path
import re
p=Path(__file__).resolve().parent
source=Path('tests/out/benchmarks/pinned/nofib/spectral/hartel/nucleic2/Main.hs').read_text()
ops={'_ADD_':('add',6),'_SUB_':('sub',6),'_MUL_':('mul',7)}
functions={'_NEG_':('negative',1),'_SQRT_':('sqrt',1),'_SIN_':('sin',1),'_COS_':('cos',1),'_ATAN2_':('atan2',2)}
class Expr:
 def __init__(self,text):
  text=re.sub(r'FL_LIT\(([-+0-9.eE]+)\)',r'\1',text)
  self.tokens=re.findall(r'_?[A-Za-z][A-Za-z_0-9]*|[-+]?(?:\d+\.\d*|\d+)(?:[eE][-+]?\d+)?|[()]',text);self.i=0
 def expr(self,minprec=0):
  t=self.tokens[self.i];self.i+=1
  if t=='(':
   value=self.expr();assert self.tokens[self.i]==')';self.i+=1
  elif t in functions:
   name,n=functions[t];value=(name,[self.expr(10)for _ in range(n)])
  elif t in ['Pt','Tfo']:
   value=(t,[self.expr(10)for _ in range(3 if t=='Pt'else 12)])
  elif re.fullmatch(r'[-+]?[0-9.]+',t):value=('literal',t)
  else:value=('variable',t)
  while self.i<len(self.tokens)and self.tokens[self.i]in ops and ops[self.tokens[self.i]][1]>=minprec:
   name,prec=ops[self.tokens[self.i]];self.i+=1
   value=(name,[value,self.expr(prec+1)])
  return value
 def parse(self):
  result=self.expr();assert self.i==len(self.tokens),self.tokens[self.i:];return result
def render(node):
 tag,args=node
 if tag=='variable':return 'real '+args
 if tag=='literal':return 'R.round '+args.replace('-','~')
 if tag in ['Pt','Tfo']:return tag+'('+','.join('D.delay(fn()=>'+render(a)+')'for a in args)+')'
 return 'R.'+tag+'('+','.join(render(a)for a in args)+')'
def get(start,end):
 s=source[source.index(start):source.index(end,source.index(start))]
 s=re.sub(r'--[^\n]*','',s)
 return s.split('=',1)[1].strip()
def definition(name,patterns,rhs):
 tree=Expr(rhs).parse()
 return ' fun '+name+' '+ ' '.join('arg'+str(i)for i in range(len(patterns)))+'=D.delay(fn()=>\n   let '+ ' '.join('val '+pat+'=D.force arg'+str(i)for i,pat in enumerate(patterns))+'\n   in '+render(tree)+'end)\n'
out=definition('tfo_apply',['Tfo(a,b,c,d,e,f,g,h,i,tx,ty,tz)','Pt(x,y,z)'],get('tfo_apply (','-- The function "tfo-combine"'))
out+=definition('tfo_combine',['Tfo('+','.join('a_'+n for n in ['a','b','c','d','e','f','g','h','i','tx','ty','tz'])+')',
 'Tfo('+','.join('b_'+n for n in ['a','b','c','d','e','f','g','h','i','tx','ty','tz'])+')'],get('tfo_combine\n','-- The function "tfo-inv-ortho"'))
out+=definition('tfo_inv_ortho',['Tfo(a,b,c,d,e,f,g,h,i,tx,ty,tz)'],get('tfo_inv_ortho (','-- Given three points'))
(p/'geometry-generated.sml').write_text(out)
print('three geometry functions generated from reviewed arithmetic expression trees')
