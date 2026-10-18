from pathlib import Path
import importlib.util,re
p=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('geometry',p/'generate-geometry.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
s=g.get('tfo_align (','-- -- NUCLEIC ACID')
rhs,where=s.split('where',1)
# Source where bindings are acyclic here; retain every original shared root.
matches=list(re.finditer(r'(?m)^\s{6}([a-z][A-Za-z0-9_]*)\s*=',where))
assert len(matches)==21,[(m[1])for m in matches]
bindings=[]
for i,m in enumerate(matches):
 name=m[1];body=where[m.end():matches[i+1].start()if i+1<len(matches)else len(where)].strip()
 if name=='rotpy':
  value='pt_sub(D.delay(fn()=>Pt(x2,y2,z2)))(D.delay(fn()=>Pt(x1,y1,z1)))'
 elif name in ['phi','theta']:value=('pt_phi'if name=='phi'else'pt_theta')+' rotpy'
 elif name=='rho':value='pt_theta rotpz'
 else:
  tree=g.Expr(body).parse();value='D.delay(fn()=>'+g.render(tree)+')'
 bindings.append('       val '+name+'='+value)
out=' fun tfo_align arg0 arg1 arg2=D.delay(fn()=>\n   let val Pt(x1,y1,z1)=D.force arg0\n       val Pt(x2,y2,z2)=D.force arg1\n       val Pt(x3,y3,z3)=D.force arg2\n'+'\n'.join(bindings)+'\n   in '+g.render(g.Expr(rhs).parse())+'end)\n'
(p/'geometry-align.sml').write_text(out)
print('tfo_align retains',len(bindings),'shared source roots')
