from pathlib import Path
import json,math
p=Path(__file__).resolve().parent
observations=json.loads((p/'observations.json').read_text())
states={}
u={(i,j):0.0 for i in range(9)for j in range(8)}
v={(i,j):0.0 for i in range(8)for j in range(9)}
h={(i,j):float(3*i)/7.0 for i in range(8)for j in range(8)}
cux=9.8*(800.0/(2.0*10000.0));cuy=cux;ccr=0.000125*(800.0/4.0);cfr=2.0*800.0
chx=800.0/(4.0*10000.0);chy=chx;lam=0.0024
wanted={r['steps']for r in observations}
for step in range(max(wanted)+1):
 if step in wanted:states[step]=(dict(u),dict(v),dict(h))
 un={}
 for i in range(9):
  for j in range(8):
   if i in [0,8]:un[i,j]=0.0;continue
   height=cux*(h[i,j]-h[i-1,j])
   coriolis=ccr*(v[i-1,j]+(v[i-1,j+1]+(v[i,j]+v[i,j+1])))
   friction=cfr*((lam*u[i,j]-0.0)/(30.0+30.0))
   un[i,j]=(u[i,j]-height)+(coriolis-friction)
 vn={}
 for i in range(8):
  for j in range(9):
   if j in [0,8]:vn[i,j]=0.0;continue
   height=cuy*(h[i,j]-h[i,j-1])
   coriolis=ccr*(un[i,j-1]+(un[i+1,j-1]+(un[i,j]+un[i+1,j])))
   friction=cfr*((lam*v[i,j]-0.0)/(30.0+30.0))
   vn[i,j]=(v[i,j]-height)-(coriolis+friction)
 hn={}
 for i in range(8):
  for j in range(8):
   d1=(30.0+30.0)*un[i+1,j];d2=(30.0+30.0)*un[i,j]
   d3=(30.0+30.0)*vn[i,j+1];d4=(30.0+30.0)*vn[i,j]
   hn[i,j]=(h[i,j]-chx*(d1-d2))-chy*(d3-d4)
 u,v,h=un,vn,hn
maximum=0.0;compared=0
for row in observations:
 u,v,h=states[row['steps']]
 for matrix in row['matrices']:
  field={'u':u,'v':v,'h':h}[matrix['name'][1]]
  lo,hi,low,high=matrix['bounds']
  expected=[field[i,j]for i in range(lo,hi+1)for j in range(low,high+1)]
  assert len(expected)==len(matrix['cells'])
  for original,model in zip(matrix['cells'],expected):
   error=abs(original-model);maximum=max(maximum,error);compared+=1
   assert math.isclose(original,model,abs_tol=1e-12,rel_tol=1e-12),(row['steps'],matrix['name'],original,model)
print('PASS',compared,'original split-grid values against independent unsplit-grid stepping; maximum error',maximum)
(p/'independent-summary.json').write_text(json.dumps(dict(cases=len(observations),values=compared,max_error=maximum),indent=2)+'\n')
