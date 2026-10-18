from pathlib import Path
import re,json,struct,hashlib
p=Path(__file__).resolve().parent
up=Path('tests/out/benchmarks/pinned/nofib/spectral/hartel/nucleic2')
arity={'Nuc':30,'Tfo':12,'Pt':3,'A':8,'C':6,'G':9,'U':5}
records=[];lists={}
for filename in ['RA.hs','RC.hs','RG.hs','RU.hs']:
 text=re.sub(r'--[^\n]*','',(up/filename).read_text())
 definitions=list(re.finditer(r"(?m)^(r[A-Z][A-Za-z0-9']*)\s*=",text))
 for i,m in enumerate(definitions):
  name=m[1];body=text[m.end():definitions[i+1].start()if i+1<len(definitions)else len(text)]
  if body.lstrip().startswith('['):
   lists[name]=re.findall(r"r[A-Z][A-Za-z0-9']*",body);continue
  body=re.sub(r'FL_LIT\(([-+0-9.eE]+)\)',r'\1',body)
  tokens=re.findall(r'[A-Za-z_][A-Za-z_0-9]*|[-+]?(?:\d+\.\d*|\d+)(?:[eE][-+]?\d+)?|[()]',body)
  pos=0
  def parse():
   global pos
   t=tokens[pos];pos+=1
   if t=='(':
    value=parse();assert tokens[pos]==')';pos+=1;return value
   if t in arity:return dict(constructor=t,fields=[parse()for _ in range(arity[t])])
   return dict(decimal=t,bits=struct.unpack('>I',struct.pack('>f',float(t)))[0])
  tree=parse();assert pos==len(tokens),(name,tokens[pos:])
  records.append(dict(name=name,source=filename,value=tree))
(p/'database.json').write_text(json.dumps(dict(records=records,lists=lists),indent=2)+'\n')
print(len(records),'nucleotide conformations',len(lists),'conformation lists')
for r in records:
 assert r['value']['constructor']=='Nuc'
 assert [n['constructor']for n in r['value']['fields'][:4]]==['Tfo']*4
 assert [n['constructor']for n in r['value']['fields'][4:29]]==['Pt']*25
print('all constructor arities reviewed')
