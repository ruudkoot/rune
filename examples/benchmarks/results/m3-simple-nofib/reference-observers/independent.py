from pathlib import Path
import json,math,struct,re,importlib.util
p=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('states',p/'compare-states.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
records=[]
for n in [0,1,2,5,20,100]:
 arrays,scalar,totals=m.original(n)
 assert len(arrays)==11 and len(totals)==13
 assert all(math.isfinite(v)for items in arrays.values()for v in items.values())
 assert all(math.isfinite(v)for v in scalar.values())
 assert all(math.isfinite(v)for v in totals)
 assert 0<scalar['deltat']<=0.01
 assert totals[11]==scalar['deltat']and totals[12]==scalar['error']
 sums=[]
 for items in arrays.values():
  total=0.0
  for value in items.values():total=total+value
  sums.append(total)
 assert sums==totals[:11]
 records.append(dict(steps=n,arrays=len(arrays),cells=sum(map(len,arrays.values())),totals=13,finite=True,row_major_sums_match=True))
initial,_,_=m.original(0)
checks=0
for k in range(2,101):
 for l in range(2,101):
  angle=(-0.5+(l-2)/98)*math.pi
  for name,wanted in [('r',(10+k-2)*math.cos(angle)),('z',(10+k-2)*math.sin(angle))]:
   assert abs(initial[name][k,l]-wanted)<=1e-12+1e-11*abs(wanted);checks+=1
for zone,rho in initial['rho'].items():
 assert rho==1.4
 k,l=zone;interior=2<k<=100 and 2<l<=100
 assert initial['theta'][zone]==(10.0 if interior else 0.0)
 if interior:
  assert abs(initial['p'][zone]-(0.06698*1.4)*10.0)<1e-14
  assert initial['epsilon'][zone]==1.0
  checks+=2
 if (k==2 or k==101)and(l==2 or l==101):assert initial['theta'][zone]==0.0
# Bound checks reject independent perturbations at zero, tiny and large values.
def close(e,x):return math.isfinite(x)and abs(e-x)<=1e-12+1e-11*abs(e)
perturbations=[(0.0,2e-12),(1e-9,1e-9+2e-12),(1e6,1e6+2e-5)]
assert all(not close(e,x)for e,x in perturbations)
assert not close(0.0,float('nan'))and not close(0.0,float('inf'))
(p/'independent-results.json').write_text(json.dumps(dict(states=records,initial_formula_checks=checks,rejected_perturbations=perturbations,scope='Independent geometry, initial equations, finite states and scalar reductions; not a second full solver or physical-model proof'),indent=2)+'\n')
print(len(records),'complete original finite states; row-major sums match; independent initial geometry/polynomial checks',checks,'; perturbed and nonfinite values rejected')
