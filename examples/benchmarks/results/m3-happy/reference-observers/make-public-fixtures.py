from pathlib import Path
import json,shutil
p=Path(__file__).resolve().parent;data=Path('tests/benchmarks/data/happy');data.mkdir(exist_ok=True)
def sml(s):
 return '"'+''.join('\\"'if c=='"'else'\\\\'if c=='\\'else c if 32<=ord(c)<127 else'\\'+str(ord(c)).zfill(3)for c in s)+'"'
def integer(n):return str(n).replace('-','~')
def slist(xs):return '['+','.join(integer(n)for n in xs)+']'
literals=[]
for r in json.loads((p/'literal-cases.json').read_text()):
 ref=json.loads((p/'literal-data'/(r['name']+'.reference')).read_text())
 result='NONE'if ref[0]=='none'else'SOME('+sml(ref[1])+','+sml(ref[2])+')'
 literals.append('('+sml(r['name'])+','+sml(r['mode'])+','+sml(r['input'])+','+result+')')
codes=[]
for r in json.loads((p/'code-cases.json').read_text()):
 ref=json.loads((p/'code-data'/(r['name']+'.reference')).read_text())
 result=('CodeOK('+sml(ref[1])+','+slist(ref[2])+')'if ref[0]=='ok'else
         'CodeErrors['+','.join(sml(x)for x in ref[1])+']'if ref[0]=='errors'else'CodeException')
 codes.append('('+sml(r['name'])+','+str(r['arity'])+','+sml(r['code'])+','+result+')')
sets=[]
for i,(xs,ys,m)in enumerate(json.loads((p/'set-cases.json').read_text())):
 sets.append('('+str(i)+','+slist(xs)+','+slist(ys)+','+str(m)+')')
 (data/('set-'+str(i)+'.reference')).write_bytes((p/'set-data'/(str(i)+'.reference')).read_bytes())
names=[r['name']for r in json.loads((p/'codegen-cases.json').read_text())if r['name']!='default']
for n in names:
 for src,dst in [(p/'grammar-data'/(n+'.input'),n+'.y'),(p/'codegen-data'/(n+'.reference'),n+'.reference'),(p/'end-to-end-data'/n/'stderr',n+'.warnings')]:
  shutil.copyfile(src,data/dst)
src=(data/'precedence.reference').read_bytes();(data/'wrong.reference').write_bytes(bytes([src[0]^1])+src[1:])
(data/'truncated.reference').write_bytes(src[:-1])
(data/'wrong.warnings').write_text('wrong\n')
fixtures='(* Reviewed original-GHC observations; see happy-lazy/NOTICE and results archive. *)\nstructure BenchHappyFixtures=struct\n datatype codeResult=CodeOK of string*int list|CodeErrors of string list|CodeException\n'
fixtures+=' val literals=['+',\n'.join(literals)+']\n val codes=['+',\n'.join(codes)+']\n val sets=['+',\n'.join(sets)+']\n'
fixtures+=' val grammars=['+','.join(sml(n)for n in names)+']\nend\n'
Path('tests/benchmarks/happy-fixtures.sml').write_text(fixtures)
(data/'FILES').write_text(''.join(str(f.relative_to(data))+'\n'for f in sorted(data.rglob('*'))if f.is_file()and f.name!='FILES'))
print(len(literals),'literal fixtures',len(codes),'semantic-action fixtures',len(sets),'set fixtures',len(names),'grammar fixtures')
