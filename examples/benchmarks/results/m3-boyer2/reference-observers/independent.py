from pathlib import Path
import json,ast,functools,itertools,sys
r=Path(__file__).resolve().parent;sys.setrecursionlimit(100000)
def tokens(s):
 out=[];i=0
 while i<len(s):
  while i<len(s)and s[i]==' ':i+=1
  if i==len(s):out.append('');break
  if s[i]in'()':out.append(s[i]);i+=1;continue
  j=i
  while i<len(s)and s[i]not in'() ':i+=1
  out.append(s[j:i])
 return out
def parse(s):
 ts=tokens(s)
 if not ts or ts[0]!='(':return()
 def sub(i):
  values=[]
  while i<len(ts):
   token=ts[i];i+=1
   if token==')':return i,tuple(values)
   if token=='(':i,value=sub(i);values.append(value)
   else:values.append(token)
  return i,tuple(values)
 i,value=sub(1);return value if i==len(ts)else()
rulemap={}
for text in json.loads((r/'rules.json').read_text()):
 rule=parse(text)
 if not rule:continue
 assert rule[0]=='equal'and isinstance(rule[1],tuple)
 rulemap.setdefault(rule[1][0],[]).insert(0,(rule[1],rule[2] if len(rule)>2 else ()))
def bind(term,pattern,env):
 if isinstance(pattern,str):
  if pattern in env:return env[pattern]==term
  env[pattern]=term;return True
 if isinstance(term,str):return False
 def head(t):return t[0]if t else()
 if head(term)!=head(pattern):return False
 first=term[1:]if term else();second=pattern[1:]if pattern else()
 for index,item in enumerate(first):
  value=second[index]if index<len(second)else()
  if not bind(item,value,env):return False
 return True

def subst(term,env):
 if isinstance(term,str):return env.get(term,term)
 if not term:return()
 return(term[0],)+tuple(subst(t,env)for t in term[1:])
@functools.lru_cache(None)
def rewrite(term):
 if isinstance(term,str)or not term:return term
 current=(term[0],)+tuple(rewrite(t)for t in term[1:])
 for pattern,result in rulemap.get(term[0],[]):
  env={}
  if bind(current,pattern,env):return rewrite(subst(result,env))
 return current

def serialize(term):
 if isinstance(term,str):return term
 tail='()'
 for value in reversed(term):tail='('+serialize(value)+' . '+tail+')'
 return tail

def statement(i):
 c='c'+str(i)
 values={'x':('f',('plus',('plus','a','b'),('plus',c,('zero',)))),
         'y':('f',('times',('times','a','b'),('plus',c,'d'))),
         'z':('f',('reverse',('append',('append','a','b'),('[]',)))),
         'u':('equal',('plus','a','b'),('difference','x','y')),
         'w':('lessp',('remainder','a','b'),('member','a',('length','b')))}
 implies=lambda a,b:('implies',a,b)
 theorem=implies(('and',implies('x','y'),('and',implies('y','z'),('and',implies('z','u'),implies('u','w')))),implies('x','w'))
 return subst(theorem,values)
def truthcheck(normal):
 variables=set()
 def collect(t):
  if t in [('t',),('f',),()]:return
  if isinstance(t,tuple)and len(t)==4 and t[0]=='if':
   if t[1]not in[('t',),('f',)]:variables.add(t[1])
   collect(t[2]);collect(t[3])
  else:variables.add(t)
 collect(normal);variables=list(variables);assert len(variables)<=16,len(variables)
 def evaluate(t,env):
  if t==('t',):return True
  if t==('f',)or t==():return False
  if isinstance(t,tuple)and len(t)==4 and t[0]=='if':
   condition=True if t[1]==('t',)else False if t[1]==('f',)else env[t[1]]
   return evaluate(t[2]if condition else t[3],env)
  return env[t]
 return all(evaluate(normal,dict(zip(variables,values)))for values in itertools.product([False,True],repeat=len(variables))),len(variables)
for i in [1,2,60,600]:
 lines=(r/('observer-'+str(i)+'.txt')).read_text().splitlines();assert ast.literal_eval(lines[0])==sorted((key,len(values))for key,values in rulemap.items())
 term=statement(i);assert serialize(term)==lines[1],('input',i)
 normal=rewrite(term);text=serialize(normal);assert text==lines[2],('normal',i)
 valid,n=truthcheck(normal);assert valid and lines[3]=='True'
 (r/(str(i)+'.normal')).write_text(text+'\n');print('PASS independent full input/normal form, original LUT and all',2**n,'truth assignments:',i,len(text),'bytes',flush=True)
