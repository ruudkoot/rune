from pathlib import Path
import re
p=Path(__file__).resolve().parent;t=(p/'source/Main.hs').read_text()
defs=re.findall(r'data\n\s+(T_pt\w+)=([^;]+);',t)
assert len(defs)==18,len(defs)
lines=[];ctors={}
for name,body in defs:
 constructors=[]
 for part in body.split('|'):
  ctor,*fields=part.split();ctors[ctor]=fields
  types=[{'T_string':'stringCell','Int':'int D.t','Char':'char D.t'}.get(f,f)for f in fields]
  constructors.append(ctor+(' of '+'*'.join(types)if types else''))
 lines.append(('datatype 'if not lines else'and ')+name+'_node='+'|'.join(constructors))
lines.append('withtype stringCell=char list D.t')
for name,_ in defs:lines.append('and '+name+'='+name+'_node D.t')
(p/'ast-declarations.sml').write_text('\n'.join(lines)+'\n')
(p/'ast-constructors.json').write_text(__import__('json').dumps(ctors,indent=2)+'\n')
print('typed AST datatypes',len(defs))
