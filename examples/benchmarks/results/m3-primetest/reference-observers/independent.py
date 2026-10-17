from pathlib import Path
import json
p=Path(__file__).resolve().parent
def draw(state):
 s1,s2=state
 k=s1//53668;a=40014*(s1-k*53668)-k*12211;s1=a+2147483563 if a<0 else a
 k=s2//52774;a=40692*(s2-k*52774)-k*3791;s2=a+2147483399 if a<0 else a
 z=s1-s2
 return z+2147483562 if z<1 else z,(s1,s2)
def peek(state,count=4):
 values=[]
 for _ in range(count):
  x,state=draw(state);values.append(x)
 return values
def random(bound,state):
 digits=[];n=bound
 while n:
  n,r=divmod(n,65536);digits.insert(0,r)
 draws=[]
 for _ in digits:
  r,state=draw(state);draws.append(r)
 values=[];at_bound=True
 for i,(n,r)in enumerate(zip(digits,draws)):
  if not at_bound:values.append(r%65536)
  elif i==len(digits)-1:values.append(r%n)
  else:
   t=r%(n+1);values.append(t);at_bound=(t==n)
 x=0
 for v in values:x=x*65536+v
 assert 0<=x<bound
 return x,state,len(draws)
def test(n,state,rounds=100):
 if n<=1 or n%2==0:return n==2,state,0,0
 q=n-1;k=0
 while q%2==0:k+=1;q//=2
 count=0
 for trial in range(rounds):
  x,state,used=random(n-2,state);count+=used;t=pow(2+x,q,n)
  passed=(t==1 or t==n-1)
  if not passed:
   for _ in range(k-1):
    t=t*t%n
    if t==n-1:passed=True;break
    if t==1:break
  if not passed:return False,state,trial+1,count
 return True,state,rounds,count
metadata=[]
for name,file,observed in [('small','small-cases.input','small.observe'),('fast','source/primetest.faststdin','fast.observe'),('normal','source/primetest.stdin',None),('slow','source/primetest.slowstdin',None)]:
 numbers=list(map(int,(p/file).read_text().splitlines()));state=(111,47);rows=[];output=[]
 for i,n in enumerate(numbers):
  ok,state,trials,draws=test(n,state);after=peek(state)
  output.append('Probably prime'if ok else'Composite');rows.append(dict(index=i,n=str(n),passed=ok,trials=trials,raw_draws=draws,after=after))
 if observed:
  lines=(p/observed).read_text().splitlines()
  assert lines[0]=='raw '+' '.join(map(str,peek((111,47),16)))
  assert lines[1:]==[f'{r["index"]} {r["n"]} {int(r["passed"])} '+' '.join(map(str,r['after']))for r in rows]
 else:
  fixture='primetest.'+('stdin'if name=='normal'else'slowstdin')
  assert ''.join(output)==(p/'source'/fixture.replace('stdin','stdout')).read_text()
 metadata.append(dict(input=name,cases=len(rows),trials=sum(r['trials']for r in rows),raw_draws=sum(r['raw_draws']for r in rows),rows=rows))
(p/'independent-metadata.json').write_text(json.dumps(dict(scope='Separate Python integer/pow and PRNG model; fixed source witnesses are not a proof of primality or a statistical independence guarantee',inputs=metadata),indent=2)+'\n')
print('Independent model agrees on 380 candidates, raw prefixes and small/FAST successor states')
