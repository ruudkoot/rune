from pathlib import Path
import json,sys,collections
sys.setrecursionlimit(100000)
p=Path(__file__).resolve().parent
def sequence(tree):
 out=[]
 while tree[0]=='(:)':
  assert len(tree)==3;out.append(tree[1]);tree=tree[2]
 assert tree==['[]']
 return out
schemas={
 'F_Caf':['names','expr'],'F_Def':['text','names','expr','where'],
 'F_Where':['program'],'C_NoWhere':[],
 'F_Tail':['label','expr'],'F_Cons':['label','expr','expr'],
 'F_Map':['label','text','exprs'],'F_Maps':['label','text','text','expr','exprs'],
 'F_Ap':['text','exprs'],'F_Tuple':['exprs'],'F_Var':['text'],'F_Lit':['text']}
owners={c:('def'if c in['F_Caf','F_Def']else'where'if c in['F_Where','C_NoWhere']else'expr')for c in schemas}
def check(value,kind,counts,labels):
 if kind=='text':
  assert isinstance(value,str)and value.isascii();return
 if kind=='label':
  assert isinstance(value,int)and 0<value<2**30 and value%2==1
  labels.append(value);return
 if kind in ['names','program','exprs']:
  for element in sequence(value):check(element,{'names':'text','program':'def','exprs':'expr'}[kind],counts,labels)
  return
 constructor=value[0];assert owners[constructor]==kind
 fields=schemas[constructor];assert len(value)==len(fields)+1
 counts[constructor]+=1
 for child,field in zip(value[1:],fields):check(child,field,counts,labels)
records=[]
for name in[r.split('\t')[0]for r in(p/'observe.stdout').read_text().splitlines()]:
 for stage in ['parse','prepared','v','v0','v1','v3','v5','v6']:
  value=json.loads((p/(name+'-'+stage+'.reference')).read_text())
  if stage!='parse':value=value[4]
  counts=collections.Counter();labels=[];check(value,'program',counts,labels)
  records.append(dict(name=name,stage=stage,nodes=sum(counts.values()),labels=len(labels),maximum_label=max(labels,default=0),constructors=dict(sorted(counts.items()))))
lengths={name:len((p/(name+'-report.reference')).read_bytes())for name in{r['name']for r in records}}
order=['fft','fib','fibsum','flipflop','gamma','hamming','setreset','wave4']
cycle=[lengths[name]for name in order]
def total(n):
 q,r=divmod(n,len(cycle));return q*sum(cycle)+sum(cycle[:r])
for profile,n in [('source-fast',300),('normal',3000),('source-slow',15000)]:
 expected=total(n)
 assert(p/(profile+'.stdout')).read_text()==str(expected)+'\n'
 assert(p/'source'/('transform.'+{'source-fast':'faststdout','normal':'stdout','source-slow':'slowstdout'}[profile])).read_text()==str(expected)+'\n'
(p/'independent-results.json').write_text(json.dumps(dict(states=records,cycle=order,lengths=lengths,totals={str(n):total(n)for n in[0,1,8,9,300,3000,15000]}),indent=2)+'\n')
print('Validated',len(records),'full original ASTs;',sum(r['nodes']for r in records),'nodes; source label/type/arity/ASCII bounds; independent cycle totals match all three golden fixtures')
