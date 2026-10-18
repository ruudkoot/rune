from pathlib import Path
import re,json,subprocess
p=Path(__file__).resolve().parent
src=(p/'source/Parser.hs').read_text()
action_rows={}
for state,arg,operation,target in re.findall(r'^action_(\d+)\s+(\(\d+\)|_)\s*=\s*(happy\w+)(?:\s+action_(\d+))?\s*$',src,re.M):
 state=int(state);arg='_'if arg=='_'else str(int(arg[1:-1]))
 if operation=='happyShift':rhs='shift action_'+target
 elif operation=='happyGoto':rhs='goto action_'+target
 elif operation=='happyAccept':rhs='accept'
 elif operation=='happyFail':rhs='failure'
 elif operation.startswith('happyReduce_'):rhs='reduce_'+operation[len('happyReduce_'):]
 else:raise AssertionError(operation)
 action_rows.setdefault(state,[]).append((arg,rhs))
assert sorted(action_rows)==list(range(73))
out=[]
for state,rows in sorted(action_rows.items()):
 assert rows[-1][0]=='_',state
 out.append((' fun 'if state==0 else' and ')+'action_'+str(state)+' symbol=case symbol of\n   '+'\n  |'.join(arg+'=>'+rhs for arg,rhs in rows))
reductions=[]
for n,kind,count,nt in re.findall(r'^happyReduce_(\d+)\s*=\s*(happyReduce|happyMonadReduce|happySpecReduce_[0-3])\s+(?:(\d+)\s+)?(\d+)\s+happyReduction_\d+\s*$',src,re.M):
 n=int(n);nt=int(nt)
 if kind.startswith('happySpecReduce_'):
  k=int(kind[-1]);assert count==''
  rhs='spec'+str(k)+' '+str(nt)+' reduction'+str(n)
 elif kind=='happyReduce':
  k=int(count);rhs='reduce '+str(k)+' '+str(nt)+' reduction'+str(n)
 elif kind=='happyMonadReduce':
  k=int(count);rhs='monadReduce '+str(k)+' '+str(nt)+' reduction'+str(n)
 else:raise AssertionError(kind)
 reductions.append((n,kind,k,nt))
 out.append(' and reduce_'+str(n)+' j token st states stack='+rhs+' j token st states stack')
assert sorted(n for n,_,_,_ in reductions)==list(range(1,41))
(p/'parser-actions.sml').write_text('\n'.join(out)+'\n')
(p/'parser-action-review.json').write_text(json.dumps({'states':action_rows,'reductions':reductions,'source':'pinned gc/happy/Parser.hs; direct higher-order SML action functions, not a runtime table interpreter'},indent=2)+'\n')
kernel=''.join((p/name).read_text()for name in ['types.sml','reductions.sml','parser-actions.sml','parser-runtime.sml'])+'\nend\n'
(p/'parser-kernel.sml').write_text(kernel)
with(p/'parser-build.log').open('w')as log:subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml',str(p/'lexer.sml'),str(p/'parser-kernel.sml'),'-o',str(p/'parser-kernel.rbc')],stdout=log,stderr=subprocess.STDOUT,check=True)
print('73 action functions,40 typed reductions,source error recovery and continuation runtime compiled')
