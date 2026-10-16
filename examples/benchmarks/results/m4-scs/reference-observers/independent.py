from pathlib import Path
from fractions import Fraction as F
import math, re, ast, json, struct
p=Path(__file__).resolve().parent
scales=dict(zip('afpnumkMGTPE',[-18,-15,-12,-9,-6,-3,3,6,9,12,15,18]))
def quantity(text):
 text=text.strip();suffix=text[-1]if text[-1]in scales else''
 value=F(text[:-1]if suffix else text)
 return value*(F(10)**scales[suffix]if suffix else 1)
def read_circuit():
 names=['v:ground'];elements=[]
 for line in(p/'runtime_files/inverter.in').read_text().splitlines():
  if not line.strip():continue
  tag,name,plus,minus,rest=line.split(None,4);labels=['i:'+name,'v:'+plus,'v:'+minus]
  for label in labels:
   if label not in names:names.append(label)
  if tag in'vi':args=[(float(quantity(a)),float(quantity(b)))for a,b in re.findall(r'\(([^,]+),([^\)]+)\)',rest)]
  else:args=[quantity(x)for x in rest.split()]
  elements.append((*(names.index(label)for label in labels),tag,args))
 return elements,names
circuit,names=read_circuit();n=len(names)-1
zero=lambda rows,cols:[[F(0)for _ in range(cols)]for _ in range(rows)]
def unit(size):return[[F(r==c)for c in range(size)]for r in range(size)]
def transpose(a):return[list(row)for row in zip(*a)]
def multiply(a,b):
 result=zero(len(a),len(b[0]))
 for r in range(len(a)):
  for t in range(len(b)):
   for c in range(len(b[0])):result[r][c]+=a[r][t]*b[t][c]
 return result
def add(a,b,sign=1):return[[x+sign*y for x,y in zip(row,other)]for row,other in zip(a,b)]
def scale(a,factor):return[[factor*x for x in row]for row in a]
def gauss(a):
 size=len(a);a=[row[:]for row in a];inverse=unit(size);free=list(range(size))
 for c in range(size):
  row=max(free,key=lambda r:abs(a[r][c]));value=a[row][c]
  if not value:continue
  a[c],a[row]=a[row],a[c];inverse[c],inverse[row]=inverse[row],inverse[c]
  a[c]=[x/value for x in a[c]];inverse[c]=[x/value for x in inverse[c]]
  for r in range(size):
   if r==c:continue
   coefficient=a[r][c];a[r]=[x-coefficient*y for x,y in zip(a[r],a[c])];inverse[r]=[x-coefficient*y for x,y in zip(inverse[r],inverse[c])]
  free.remove(c)
 return free,a,inverse
def prepare(dt):
 a=zero(n,n);d=zero(n,n);initial=[F(0)]*n
 def stamp(r,c,value):
  if r and c:a[r-1][c-1]+=value
 for i,plus,minus,tag,args in circuit:
  stamp(plus,i,-1);stamp(minus,i,1)
  if tag=='g':stamp(i,minus,-args[0]);stamp(i,plus,args[0]);stamp(i,i,-1)
  elif tag=='r':stamp(i,minus,-1);stamp(i,plus,1);stamp(i,i,-args[0])
  elif tag in'cj':stamp(i,minus,-args[0]);stamp(i,plus,args[0]);d[i-1][i-1]+=1;initial[i-1]+=args[-1]
  elif tag=='l':
   stamp(i,i,args[0]);initial[i-1]+=args[-1]
   if plus:d[i-1][plus-1]+=1
   if minus:d[i-1][minus-1]-=1
  elif tag=='v':stamp(i,minus,-1);stamp(i,plus,1)
  elif tag=='i':stamp(i,i,1)
 l1,_,i1=gauss(a);l2,_,i2=gauss(transpose(a))
 if l1:
  constraint=[i1[r][:]for r in l1];freedom=transpose([i2[r][:]for r in l2]);l3,_,i3=gauss(multiply(constraint,multiply(d,freedom)));assert not l3
  correction=multiply(freedom,multiply(i3,constraint))
 else:correction=zero(n,n)
 correct=add(unit(n),multiply(d,correction),-1);correct_output=add(unit(n),multiply(correction,d),-1)
 solve=multiply(correct_output,multiply(i1,correct));scaled=scale(multiply(d,solve),dt/2)
 l4,_,i4=gauss(add(unit(n),scaled,-1));assert not l4
 integrate=multiply(i4,add(unit(n),scaled));backdate=scale(correction,1/dt)
 return initial,solve,integrate,correct,backdate
class Random:
 def __init__(self,seed):q,r=divmod(abs(seed),2147483562);self.s1=r+1;self.s2=q%2147483398+1
 def uniform(self):
  k=self.s1//53668;self.s1=40014*(self.s1-k*53668)-k*12211
  if self.s1<0:self.s1+=2147483563
  k=self.s2//52774;self.s2=40692*(self.s2-k*52774)-k*3791
  if self.s2<0:self.s2+=2147483399
  z=self.s1-self.s2
  if z<1:z+=2147483562
  return(z%1073741824)/1073741824.0
def apply(matrix,vector):
 result=[]
 for row in matrix:
  value=0.0
  for x,y in zip(vector,row):value=value+x*y
  result.append(value)
 return result
def summation(values):
 result=0.0
 for value in values:result=result+value
 return result
def simulate(prepared,dt,end):
 initial,solve,integrate,correct,backdate=prepared;initial=list(map(float,initial));solve,integrate,correct,backdate=[[[float(x)for x in row]for row in m]for m in[solve,integrate,correct,backdate]]
 rng=Random(345);delta=float(dt);e=1.6021773e-19;k=1.38066e-23;e2=e*e;kT=k
 def waveform(points,t):
  for j,(t0,v0)in enumerate(points):
   if j==len(points)-1:return v0
   t1,v1=points[j+1]
   if t<t0:return v0
   assert t0<t1
   if t<t1:return v0+(v1-v0)*(t-t0)/(t1-t0)
  raise AssertionError()
 def sources(t,old):
  state=[(((rng.uniform()+(-0.5))*2)*0.0)*e/delta for _ in range(n)]
  for i,_,_,tag,args in circuit:state[i-1]=old[i-1]if tag in'clj'else waveform(args,float(t))if tag in'vi'else 0.0
  return state
 def corrected(state,output):return apply(correct,state),[x-y for x,y in zip(output,apply(backdate,state))]
 def energy_state(state):return summation([0.5*(state[i-1]*state[i-1])/float(args[0])if tag in'cj'else 0.0 for i,_,_,tag,args in circuit])
 def energy_source(state,output):return summation([(state[i-1]*output[i-1])*delta if tag=='v'else 0.0 for i,_,_,tag,args in circuit])
 t=F(0);raw=sources(t,initial);state,output=corrected(raw,apply(solve,raw));margin=math.inf;events_count=0
 while t<=end:
  events=[];rates=[];old=energy_state(state)
  for i,_,_,tag,args in circuit:
   if tag!='j':continue
   resistance=args[1]
   for sign in[1,-1]:
    candidate=state[:];candidate[i-1]=candidate[i-1]+e if sign==1 else candidate[i-1]-e;events.append(candidate)
    changed,work=corrected(candidate,[0.0]*n);de=energy_state(changed)-old+energy_source(changed,work)
    rate=delta*kT/(e2*float(resistance))if de==0 else delta*(-de)/((e2*float(resistance))*(1-math.exp(de/kT)))
    rates.append(0.0 if rate<0 else rate)
  total=summation(rates)
  if total>1:rates=[rate/total for rate in rates]
  value=rng.uniform();cumulative=0.0;chosen=None
  for j,rate in enumerate(rates):
   cumulative=cumulative+rate;margin=min(margin,abs(value-cumulative))
   if chosen is None and value<cumulative:chosen=j
  yield t,output,margin,events_count
  if chosen is not None:
   raw=events[chosen];state,output=corrected(raw,apply(solve,raw));events_count+=1;yield t,output,margin,events_count
  t=t+dt
  if t>end:break
  raw=sources(t,apply(integrate,state));state,output=corrected(raw,apply(solve,raw))
records=[]
for profile,dt,end in [('smoke',F(1,100000000),F(1,500000)),('normal',F(1,500000000),F(1,250000)),('large',F(1,2500000000),F(1,250000))]:
 prepared=prepare(dt);reference=(p/(profile+'.prepare')).read_text().splitlines();assert ast.literal_eval(reference[0])==names;cursor=1
 for name,array in zip(['initial','solve','integrate','correct','backdate'],prepared):
  rows,cols=(n,1)if name=='initial'else(len(array),len(array[0]));assert reference[cursor]==f'{name} {rows} {cols}';cursor+=1
  values=array if name=='initial'else[x for row in array for x in row]
  for value in values:
   num,den,bits=map(int,reference[cursor].split());cursor+=1;assert value==F(num,den);assert int.from_bytes(struct.pack('>d',float(value)),'big')==bits
 assert cursor==len(reference)
 print('PASS independent exact matrices and IEEE conversion',profile,flush=True)
 with(p/(profile+'.exacttrace')).open()as reference:
  assert ast.literal_eval(reference.readline())==names[1:];rows=0;max_error=0.0;last_margin=math.inf;event_count=0
  for t,values,margin,event_count in simulate(prepared,dt,end):
   raw=reference.readline();assert raw;num,den,vector=raw.split(' ',2);assert t==F(int(num),int(den));wanted=ast.literal_eval(vector);assert len(wanted)==len(values)
   for actual,expected in zip(values,wanted):
    max_error=max(max_error,abs(actual-expected));assert actual==expected,(profile,rows,actual,expected)
   rows+=1;last_margin=margin
  assert not reference.readline()
 records.append(dict(profile=profile,rows=rows,events=event_count,max_absolute_error=max_error,minimum_cdf_margin=last_margin))
 print('PASS independent full stochastic trace',records[-1],flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
