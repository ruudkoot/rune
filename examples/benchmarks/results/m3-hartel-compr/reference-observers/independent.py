from pathlib import Path
import json
p=Path(__file__).resolve().parent;program=json.loads((p/'program.json').read_text())
def app(name,*args):return['Apl',name,list(args)]
def var(name):return['Var',name]
def const(value):return['Cns',value]
def transform(node,parent):
 tag,*args=node
 if tag=='Apl':return['Apl',args[0],[transform(x,parent)for x in args[1]]]
 if tag=='Cmp':return qualify(args[0],args[1],const('[]'),parent)
 if tag=='Let':return['Let',[[name,params,transform(body,parent)]for name,params,body in args[0]],transform(args[1],parent)]
 return node[:]
def qualify(body,quals,after,parent):
 if not quals:return app(':',transform(body,parent),transform(after,parent))
 first,*rest=quals
 if first[0]=='Fil':return app('if',transform(first[1],parent),qualify(body,rest,after,parent),transform(after,parent))
 _,n,name,values=first;helper=parent+'_h'+str(n);lst=parent+'_l'+str(n);tail=parent+'_t'+str(n)
 local=['Let',[[name,[],app('hd',var(lst))],[tail,[],app('tl',var(lst))]],qualify(body,rest,app(helper,var(tail)),parent)]
 definition=[helper,[lst],app('if',app('null',var(lst)),transform(after,parent),local)]
 return['Let',[definition],app(helper,transform(values,parent))]
def render(node):
 tag,*args=node
 if tag in['Var','Cns']:return args[0]
 if tag=='Apl':
  name,children=args
  return '('+name+''.join(' '+render(x)for x in children)+')'if name[0].isalpha()else'('+render(children[0])+name+render(children[1])+')'
 if tag=='Cmp':
  body,quals=args
  return'['+render(body)+' | '+';'.join((q[2]+' <- '+render(q[3]))if q[0]=='Gen'else render(q[1])for q in quals)+']'
 if tag=='Let':
  defs,body=args
  if not defs:return render(body)
  return'(LET '+''.join(';\n'+definition(x)for x in defs)[1:]+' IN  '+render(body)+')'
 raise AssertionError(node)
def definition(node):
 name,params,body=node;return name+''.join(' '+s for s in params)+' = '+render(body)
result=[[name,args,transform(body,name)]for name,args,body in program];text=''.join(definition(node)+';\n'for node in result).encode();assert len(text)==626
for name in ['listcompr','listcopy']:
 for n in [0,1,2]:assert text*n==(p/name/(str(n)+'.program')).read_bytes(),(name,n)
 for profile,n in [('smoke',2000),('normal',20000),('large',100000)]:assert str(len(text)*n)+'\n'==(p/name/(profile+'.stdout')).read_text()
(p/'transformed-program.json').write_text(json.dumps(result,indent=2)+'\n');(p/'independent.program').write_bytes(text)
print('PASS independent desugaring, nested parent-name scope, complete626-byte rendering and all profile lengths')
