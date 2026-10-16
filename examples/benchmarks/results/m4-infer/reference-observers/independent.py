from pathlib import Path
import re,subprocess,json
p=Path(__file__).resolve().parent
class ParseError(Exception):pass
class TypeErrorHM(Exception):pass
class Parser:
 def __init__(self,text):
  self.tokens=re.findall(r'[A-Za-z]+|[\\().=]',text);self.pos=0
  if ''.join(self.tokens)!=''.join(text.split()):raise ParseError()
 def peek(self):return self.tokens[self.pos]if self.pos<len(self.tokens)else''
 def pop(self,value=None):
  token=self.peek()
  if not token or value is not None and token!=value:raise ParseError()
  self.pos+=1;return token
 def identifier(self):
  token=self.pop()
  if not token.isalpha()or token in['let','in']:raise ParseError()
  return token
 def term(self):
  if self.peek()=='\\':
   self.pop();names=[]
   while self.peek()!='.':names.append(self.identifier())
   self.pop('.');body=self.term()
   if not names:raise ParseError()
   for name in reversed(names):body=('abs',name,body)
   return body
  if self.peek()=='let':
   self.pop();name=self.identifier();self.pop('=');value=self.term();self.pop('in');return('let',name,value,self.term())
  first=self.atom()
  while self.peek()=='('or self.peek().isalpha()and self.peek()not in['let','in']:first=('app',first,self.atom())
  return first
 def atom(self):
  if self.peek()=='(':self.pop();value=self.term();self.pop(')');return value
  return('var',self.identifier())
 def parse(self):
  term=self.term()
  if self.peek():raise ParseError()
  return term
V=lambda name:('v',name)
C=lambda name,*args:('c',name,args)
A=lambda x,y:C('->',x,y)
def free(t):return{t[1]}if t[0]=='v'else set().union(*(free(x)for x in t[2]))
class Infer:
 def __init__(self):self.counter=0;self.sub={}
 def fresh(self):x=V(self.counter);self.counter+=1;return x
 def apply(self,t):
  if t[0]=='v':return self.apply(self.sub[t[1]])if t[1]in self.sub else t
  return C(t[1],*(self.apply(x)for x in t[2]))
 def unify(self,a,b):
  a,b=self.apply(a),self.apply(b)
  if a==b:return
  if a[0]=='v':
   if a[1]in free(b):raise TypeErrorHM()
   self.sub[a[1]]=b;return
  if b[0]=='v':return self.unify(b,a)
  if a[1]!=b[1]or len(a[2])!=len(b[2]):raise TypeErrorHM()
  for x,y in zip(a[2],b[2]):self.unify(x,y)
 def instantiate(self,scheme):
  names,t=scheme;mapping={x:self.fresh()for x in names}
  def replace(t):return mapping.get(t[1],t)if t[0]=='v'else C(t[1],*(replace(x)for x in t[2]))
  return replace(t)
 def infer(self,t,env):
  if t[0]=='var':
   if t[1]not in env:raise TypeErrorHM()
   return self.apply(self.instantiate(env[t[1]]))
  if t[0]=='abs':
   fresh=self.fresh();body=self.infer(t[2],dict(env,**{t[1]:([],fresh)}));return A(self.apply(fresh),body)
  if t[0]=='app':
   first=self.infer(t[1],env);second=self.infer(t[2],env);result=self.fresh();self.unify(first,A(second,result));return self.apply(result)
  if t[0]=='let':
   value=self.apply(self.infer(t[2],env));bound=set()
   for names,ty in env.values():bound|=free(self.apply(ty))-set(names)
   quantified=sorted(free(value)-bound,key=str);return self.infer(t[3],dict(env,**{t[1]:(quantified,value)}))
  raise AssertionError(t)
def canonical(t):
 names={}
 def walk(t):
  if t[0]=='v':
   if t[1]not in names:names[t[1]]=len(names)
   return('v',names[t[1]])
  return('c',t[1],tuple(walk(x)for x in t[2]))
 return walk(t)
def parse_type(text):
 tokens=re.findall(r'->|[A-Za-z][A-Za-z0-9]*|[()]',text);pos=0
 def atom():
  nonlocal pos
  if pos>=len(tokens):raise ParseError()
  token=tokens[pos];pos+=1
  if token=='(':
   value=arrow()
   if pos>=len(tokens)or tokens[pos]!=')':raise ParseError()
   pos+=1;return value
  if not token[0].isalpha():raise ParseError()
  return C(token)if token[0].isupper()else V(token)
 def application():
  nonlocal pos
  value=atom();args=list(value[2])if value[0]=='c'else[]
  if value[0]=='c':
   while pos<len(tokens)and tokens[pos]not in[')', '->']:args.append(atom())
   value=C(value[1],*args)
  return value
 def arrow():
  nonlocal pos
  first=application()
  if pos<len(tokens)and tokens[pos]=='->':pos+=1;return A(first,arrow())
  return first
 result=arrow()
 if pos!=len(tokens):raise ParseError()
 return result
q=V('q');env={'unit':(['q'],A(q,C('List',q))),'append':(['q'],A(C('List',q),A(C('List',q),C('List',q)))),'fix':(['q'],A(A(q,q),q))}
records=[]
for profile,stem in [('smoke','fast'),('normal',''),('large','slow')]:
 for i,line in enumerate((p/('infer.'+stem+'stdin')).read_text().splitlines()):
  try:term=Parser(line).parse()
  except ParseError:status='parse-failure';term=None
  else:
   try:engine=Infer();result=engine.apply(engine.infer(term,env));status='pass'
   except TypeErrorHM:status='type-failure'
  raw=subprocess.check_output([str(p/'line-observer')],input=(line+'\n').encode(),timeout=10);(p/(profile+'-'+str(i)+'.response')).write_bytes(raw)
  assert raw.endswith(b'\n? ')
  actual='parse-failure'if raw==b'Failed to parse\n? 'else'type-failure'if raw==b'Failed to type\n? 'else'pass'
  assert actual==status,(profile,i,line,actual,status)
  if status=='pass':
   original=parse_type(raw[:-3].decode().rsplit(' : ',1)[1]);assert canonical(original)==canonical(result),(profile,i,original,result)
  records.append(dict(profile=profile,line=i,input=line,status=status,canonical_type=canonical(result)if status=='pass'else None))
 print('PASS independent parser/Algorithm W and original full responses',profile,flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
