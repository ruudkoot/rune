from pathlib import Path
import json
p=Path(__file__).resolve().parent
data=json.loads((p/'database.json').read_text())
def render(node):
 if 'decimal'in node:return 'scalar '+node['decimal'].replace('-','~')
 return 'D.delay(fn()=>'+node['constructor']+'('+','.join(render(n)for n in node['fields'])+'))'
def name(n):return n.replace("'",'Prime')
out='(* Complete selected source conformation database, original order and literals. *)\n'
for row in data['records']:out+=' val '+name(row['name'])+'='+render(row['value'])+'\n'
for n,values in data['lists'].items():
 result='F.empty()'
 for v in reversed(values):result='F.cons('+name(v)+','+result+')'
 out+=' val '+name(n)+'='+result+'\n'
(p/'database.sml').write_text(out)
# Independent GHC observations of every stored literal, before geometry.
base=[r['name']for r in data['records']]
specifics={'A':8,'C':6,'G':9,'U':5}
source='''module Database where
import Main
import Types
import qualified RA
import qualified RC
import qualified RG
import qualified RU
import GHC.Float(castFloatToWord32)
point(Pt x y z)=map castFloatToWord32[x,y,z]
matrix(Tfo a b c d e f g h i j k l)=map castFloatToWord32[a,b,c,d,e,f,g,h,i,j,k,l]
'''
for i,(ctor,n)in enumerate(specifics.items()):
 variables=['p'+str(j)for j in range(n)]
 source+=('specific'if i==0 else'specific')+'('+ctor+' '+' '.join(variables)+')=('+str(i)+',concatMap point['+','.join(variables)+'])\n'
variables=['t'+str(i)for i in range(4)]+['p'+str(i)for i in range(25)]+['x']
source+='nucleotide(Nuc '+' '.join(variables)+')=(concatMap matrix['+','.join(variables[:4])+'],concatMap point['+','.join(variables[4:29])+'],specific x)\n'
source+='main=mapM_(print . nucleotide)['+','.join(n[:2].upper()+'.'+n for n in base)+']\n'
# RA/RC/RG/RU exports omit per-conformer names; expose these only for observer.
work=p/'on-demand'
for filename in ['RA.hs','RC.hs','RG.hs','RU.hs']:
 q=work/filename;s=q.read_text();start=s.index('module ');end=s.index(' where',start)
 s=s[:start]+'module '+filename[:-3]+s[end:];q.write_text(s)
(work/'Database.hs').write_text(source)
print('database SML and independent full constant-bit observer generated')
