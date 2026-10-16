from pathlib import Path
import json,collections,ast
p=Path(__file__).resolve().parent;data=json.loads((p/'data.json').read_text());keys=data['keys'];maximum=data['maximum'];limit=len(keys)
def attribute(words):return[(word,word[0],word[-1],len(word))for word in words]
def block(words):
 known=[];result=[]
 while words:
  first,*rest=words;ends=first[1:3];updated=known+[c for c in ends if c not in known]
  determined=[word for word in rest if all(c in updated for c in word[1:3])];words=[word for word in rest if not all(c in updated for c in word[1:3])]
  result.append(first);result+=determined;known=updated
 return result
assert block(attribute(keys))==[tuple(row)for row in data['blocked']]
counts=collections.Counter(c for key in keys for c in(key[0],key[-1]));assert len(counts)==maximum and counts==dict(data['frequency'])
def solve(words):
 words=block(attribute(words));states=0
 def search(at,assocs,used,lo,hi):
  nonlocal states
  states+=1
  if at==len(words):return True,1,assocs
  _,a,z,n=words[at];env=dict(assocs)
  if a not in env and z not in env:
   choices=([(a,x)]for x in range(maximum+1))if a==z else([(a,x),(z,y)]for x in range(maximum+1)for y in range(maximum+1))
  elif a not in env:choices=([(a,x)]for x in range(maximum+1))
  elif z not in env:choices=([(z,x)]for x in range(maximum+1))
  else:choices=[[]]
  leaves=0
  for extra in choices:
   bindings=extra+assocs;lookup=dict(bindings);value=n+lookup[a]+lookup[z];low=value if lo is None else min(lo,value);high=value if hi is None else max(hi,value)
   if value in used or 1+high-low>limit:ok,count,answer=False,1,None
   else:ok,count,answer=search(at+1,bindings,used|{value},low,high)
   leaves+=count
   if ok:return True,leaves,answer
  return False,leaves,None
 ok,leaves,answer=search(0,[],set(),None,None)
 return('YesIts '+str(leaves)+' '+str(answer).replace(', ',','))if ok else('NotEver '+str(leaves)),dict(success=ok,leaves=leaves,assignments=answer,states=states)
def same(actual,expected):
 a=actual.split(' ',2);b=expected.split(' ',2);assert a[:2]==b[:2],(actual,expected)
 if a[0]=='YesIts':assert ast.literal_eval(a[2])==ast.literal_eval(b[2])
rows=[]
for parity,words in [('odd',keys+[keys[0]]),('even',keys)]:
 output,stats=solve(words);same(output,data[parity]);rows.append(dict(kind=parity,**stats));print('PASS independent',parity,stats['leaves'],stats['states'],flush=True)
for line in data['prefixes']:
 prefix,expected=line.split(':',1);output,stats=solve(keys[:int(prefix)]);same(output,expected);rows.append(dict(prefix=int(prefix),**stats));print('PASS prefix',prefix,stats['leaves'],flush=True)
for profile,n in [('smoke',6),('normal',60),('large',300)]:assert(p/(profile+'.output')).read_text()==''.join(data['odd']if i%2 else data['even']for i in range(1,n+1))
(p/'independent-results.json').write_text(json.dumps(rows,indent=2)+'\n')
