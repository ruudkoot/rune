from pathlib import Path
import json,re,functools,itertools,sys
r=Path(__file__).resolve().parent;sys.setrecursionlimit(100000);data=json.loads((r/'term-data.json').read_text())
def parse(text):
 ts=re.findall(r'\(|\)|[^ ()]+',text);at=0
 def one():
  nonlocal at
  token=ts[at];at+=1
  if token!='(':return token
  head=ts[at];at+=1;args=[]
  while ts[at]!=')':args.append(one())
  at+=1;return(head,)+tuple(args)
 value=one();assert at==len(ts);return value
rules={name:[(parse(a),parse(b))for a,b in pairs]for name,pairs in data['rules']};bindings={key:parse(text)for key,text in data['substitution']};template=parse(data['template'])
def replace_marker(t,parameter):
 if t=='?A':return parameter
 if isinstance(t,str):return t
 return(t[0],)+tuple(replace_marker(x,parameter)for x in t[1:])
def subst(t,env):
 if isinstance(t,str):return env.get(t[1:],t)
 return(t[0],)+tuple(subst(x,env)for x in t[1:])
def match(t,p,env):
 if isinstance(p,str):
  if p in env:return t==env[p]
  env[p]=t;return True
 if isinstance(t,str)or t[0]!=p[0]or len(t)!=len(p):return False
 return all(match(a,b,env)for a,b in zip(t[1:],p[1:]))
def apply(t,env):
 if isinstance(t,str):return env.get(t,t)
 return(t[0],)+tuple(apply(x,env)for x in t[1:])
@functools.lru_cache(None)
def rewrite(t):
 if isinstance(t,str):return t
 value=(t[0],)+tuple(rewrite(x)for x in t[1:])
 for pattern,result in rules.get(t[0],[]):
  env={}
  if match(value,pattern,env):return rewrite(apply(result,env))
 return value
def show(t):
 if isinstance(t,str):return t
 return '('+t[0]+''.join(' '+show(x)for x in t[1:])+')'
def truth(t):
 variables=set()
 def collect(t):
  if t in [('TRUE',),('FALSE',)]:return
  if isinstance(t,tuple)and len(t)==4 and t[0]=='IF':
   if t[1]not in[('TRUE',),('FALSE',)]:variables.add(t[1])
   collect(t[2]);collect(t[3])
  else:variables.add(t)
 collect(t);variables=list(variables);assert len(variables)<=16,len(variables)
 def evaluate(t,env):
  if t==('TRUE',):return True
  if t==('FALSE',):return False
  if isinstance(t,tuple)and len(t)==4 and t[0]=='IF':
   condition=True if t[1]==('TRUE',)else False if t[1]==('FALSE',)else env[t[1]]
   return evaluate(t[2]if condition else t[3],env)
  return env[t]
 return all(evaluate(t,dict(zip(variables,assignment)))for assignment in itertools.product([False,True],repeat=len(variables))),len(variables)
results={}
for name,expected in json.loads((r/'variable-results.json').read_text()):
 term=subst(replace_marker(template,'?'+name),bindings);normal=rewrite(term);result,n=truth(normal);assert result==expected,(name,result,expected);results[name]=dict(result=result,assignments=2**n)
 if name=='X':
  assert show(term)+'\n'==(r/'input.term').read_text();assert show(normal)+'\n'==(r/'normal.term').read_text()
 print('PASS independent complete rewriting and',2**n,'truth assignments',name,result,flush=True)
(r/'independent-results.json').write_text(json.dumps(results,indent=2)+'\n')
