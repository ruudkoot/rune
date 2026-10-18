from pathlib import Path
import json,sys
sys.setrecursionlimit(20000)
p=Path(__file__).resolve().parent
class Delay:
 def __init__(self,work):self.work=work;self.value=None;self.ready=False;self.active=False
 def force(self):
  if self.ready:return self.value
  if self.active:raise RuntimeError('recursive demand')
  self.active=True;self.value=self.work();self.ready=True;self.active=False;return self.value
def lazy(value):return Delay(lambda:value)
def validate(defs):
 names=[name for name,args,body in defs];assert len(names)==len(set(names))and'$main'in names
 def walk(expr,bound):
  kind=expr[0]
  if kind=='var':assert expr[1]in bound,('unbound',expr[1])
  elif kind=='fun':
   if expr[1].startswith('SC'):assert expr[1]in names
  elif kind=='app':walk(expr[1],bound);walk(expr[2],bound)
  elif kind=='let':
   _,rec,bindings,body=expr;keys=[name for name,rhs in bindings];assert len(keys)==len(set(keys))
   for name,rhs in bindings:walk(rhs,bound|set(keys)if rec else bound)
   walk(body,bound|set(keys))
  elif kind=='lam':raise AssertionError('lambda remains after collection')
 for name,args,body in defs:assert len(args)==len(set(args));walk(body,set(args))
def execute(input,defs=None):
 fuel=[30000];globalFns={}if defs is None else{name:(args,body)for name,args,body in defs}
 def value(expr,env):
  fuel[0]-=1
  if fuel[0]<0:raise RuntimeError('evaluation budget')
  kind=expr[0]
  if kind in['num','bool']:return expr[1]
  if kind=='var':return env[expr[1]].force()
  if kind=='fun':return('fun',expr[1],[])
  if kind=='lam':return('closure',expr[1],expr[2],env)
  if kind=='app':return apply(value(expr[1],env),Delay(lambda:value(expr[2],env)))
  if kind=='let':
   _,rec,bindings,body=expr;extended=dict(env);rhsEnv=extended if rec else env
   for name,rhs in bindings:extended[name]=Delay(lambda rhs=rhs:value(rhs,rhsEnv))
   return value(body,extended)
  raise AssertionError(kind)
 def apply(function,arg):
  if function[0]=='closure':
   _,args,body,env=function;new=dict(env);new[args[0]]=arg
   return value(body,new)if len(args)==1 else('closure',args[1:],body,new)
  _,name,args=function;args=args+[arg]
  if name in globalFns:
   parameters,body=globalFns[name]
   return value(body,dict(zip(parameters,args)))if len(args)==len(parameters)else('fun',name,args)
  arity=3 if name=='if'else 2
  if len(args)<arity:return('fun',name,args)
  if name=='if':return args[1 if args[0].force()else 2].force()
  a,b=[x.force()for x in args]
  return {'+':lambda:a+b,'-':lambda:a-b,'*':lambda:a*b,'==':lambda:a==b}[name]()
 return value(input,{})if defs is None else value(globalFns['$main'][1],{})
records=[]
for name,input,plain,full in json.loads((p/'ast-observations.json').read_text()):
 validate(plain);validate(full)
 record=dict(name=name,plain_closed=True,full_closed=True)
 if name!='fixed-program':
  a=execute(input);b=execute(input,plain);c=execute(input,full);assert a==b==c,(name,a,b,c)
  assert a==(720 if name=='factorial'else 42)
  record['result']=a
 records.append(record);print(record,flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
