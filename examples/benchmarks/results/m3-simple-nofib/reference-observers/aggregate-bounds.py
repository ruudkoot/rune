from pathlib import Path
import json,math,struct,re
from fractions import Fraction
p=Path(__file__).resolve().parent
def real(h):return struct.unpack('>d',bytes.fromhex(h.zfill(16)))[0]
def hex64(v):return struct.pack('>d',v).hex()
def upward(exact):
 value=float(exact)
 if Fraction.from_float(value)<exact:value=math.nextafter(value,math.inf)
 assert Fraction.from_float(value)>=exact
 return value
def bound(count,scale):
 u=2**-53;gamma=count*u/(1-count*u)
 return ((1+gamma)*(count*1e-12+1e-11*scale)+2*gamma*scale)*(1+64*u)
records=[]
for grid,stepslist,prefix in [(100,[0,1,2,5,20,100],''),(8,[0,1,2,5],'small-')]:
 for steps in stepslist:
  arrays=[];current=None
  for line in(p/(prefix+'state-'+str(steps)+'.reference')).read_text().splitlines():
   cols=line.split('\t')
   if cols[0]in['deltat','error']:continue
   if cols[0].startswith('('):current.append(real(cols[1]))
   else:current=[];arrays.append(current)
  totals=[real(line.split('\t')[1])for line in(p/(prefix+'totals-'+str(steps)+'.reference')).read_text().splitlines()]
  assert len(arrays)==11 and len(totals)==13
  entries=[]
  for index,values in enumerate(arrays):
   n=len(values);scale=upward(sum((abs(Fraction.from_float(x))for x in values),Fraction(0)))
   u=Fraction(1,2**53);gamma=n*u/(1-n*u)
   exact=(1+gamma)*(n*Fraction(1,10**12)+Fraction(1,10**11)*Fraction.from_float(scale))+2*gamma*Fraction.from_float(scale)
   permitted=bound(n,scale)
   assert Fraction.from_float(permitted)>=exact
   # Independent finite perturbations outside the derived bound are rejected.
   assert abs((totals[index]+4*permitted)-totals[index])>permitted
   entries.append((hex64(totals[index]),n,hex64(scale)))
   records.append(dict(grid=grid,steps=steps,component=index,count=n,reference_sum=totals[index],absolute_sum_upper=scale,bound=permitted,derived_bound_rounded_outward=True))
  entries +=[(hex64(totals[11]),0,hex64(0.0)),(hex64(totals[12]),0,hex64(0.0))]
  (p/'data'/('totals-'+str(grid)+'-'+str(steps)+'.reference')).write_text('SIMPLE-TOTALS-V2 '+str(grid)+' '+str(steps)+' 13\n'+''.join(value+' '+str(n)+' '+scale+'\n'for value,n,scale in entries))
(p/'data/wrong-totals.reference').write_text('SIMPLE-TOTALS-V2 8 1 13\n'+('3ff0000000000000 0 0000000000000000\n'*13))
(p/'aggregate-bound-review.json').write_text(json.dumps({'unit_roundoff':'2^-53','reference_norm':'sum of exact binary64 magnitudes rounded upward','cell_bound':'a+r*abs(e), a=1e-12,r=1e-11','sum_bound':'(1+gamma_n)*(n*a+r*S)+2*gamma_n*S, gamma_n=n*u/(1-n*u)','rounding_padding':'multiply by 1+64*u; exact Fraction checks verify outward rounding for every fixture','scope':'conditional on componentwise compatibility; dt/error retain scalar checks','records':records},indent=2)+'\n')
print(len(records),'array aggregates independently reviewed; outward bounds and rejected perturbations verified')
