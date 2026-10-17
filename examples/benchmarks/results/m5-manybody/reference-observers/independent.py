from pathlib import Path
import re,math,json
p=Path(__file__).resolve().parent;root=p.parents[3]
source=(root/'examples/benchmarks/shared/ocaml-random.sml').read_text()
seed=list(map(int,re.findall(r'0w(\d+)',source.split('val defaultWords = Vector.fromList [',1)[1].split('] : Word32.word vector',1)[0])))
assert len(seed)==55
solar=(4.0*3.141592653589793)*3.141592653589793;days=365.24
class Random:
 def __init__(self):self.words=seed.copy();self.index=0
 def bits(self):
  self.index=(self.index+1)%55;i=self.index;c=self.words[i]
  r=(self.words[(i+24)%55]+(c^((c>>25)&31)))&0x3fffffff
  self.words[i]=r;return r
 def real(self,b):
  r1=float(self.bits());r2=float(self.bits())
  return ((r1/1073741824.0+r2)/1073741824.0)*b
def initial(n):
 r=Random();b=[]
 for i in range(n):
  mass=r.real(10.0)*solar;vz=r.real(5.0)*days;vy=r.real(4.0)*days;vx=r.real(5.0)*days
  z=r.real(10.0);y=r.real(10.0);x=r.real(10.0);b.append([x,y,z,vx,vy,vz,mass])
 momentum=[0.0,0.0,0.0]
 for x in b:
  for k in range(3):momentum[k]+=x[k+3]*x[6]
 for k in range(3):b[0][k+3]=-momentum[k]/solar
 return b
def advance(b):
 for i,x in enumerate(b):
  for j,y in enumerate(b):
   if i==j:continue
   dx=x[0]-y[0];dy=x[1]-y[1];dz=x[2]-y[2]
   dist2=dx*dx+dy*dy+dz*dz;mag=0.01/(dist2*math.sqrt(dist2))
   for k,d in enumerate([dx,dy,dz]):x[k+3]-=d*y[6]*mag
 for x in b:
  for k in range(3):x[k]+=0.01*x[k+3]
def energy(b):
 e=0.0
 for i,x in enumerate(b):
  e+=((0.5*x[6])*(x[3]*x[3]+x[4]*x[4]+x[5]*x[5]))
  for y in b[i+1:]:
   dx=x[0]-y[0];dy=x[1]-y[1];dz=x[2]-y[2]
   e-=(x[6]*y[6])/math.sqrt(dx*dx+dy*dy+dz*dz)
 return e
results=[]
for name,steps,count in [('one',0,1),('small-zero',0,4),('small-one',1,4),('small-two',2,4),('smoke',1,16),('normal',20,256),('normal-zero',0,256),('large-zero',0,1024)]:
 bodies=initial(count);first=energy(bodies)
 for _ in range(steps):advance(bodies)
 actual=[first,energy(bodies)]+sum(bodies,[]);expected=list(map(float,(p/(name+'.state')).read_text().split()))
 assert len(actual)==len(expected)==2+7*count
 errors=[abs(a-b)/(1+abs(b))for a,b in zip(actual,expected)]
 assert max(errors)<1e-14,(name,max(errors))
 results.append(dict(profile=name,numbers=len(actual),maximum_scaled_difference=max(errors),exact_binary64_matches=sum(a==b for a,b in zip(actual,expected))))
meta=dict(scope='Separate Python binary64 generator/ordered-pair/energy model; default seed words retained from pinned OCaml derivation; full original large integration is reference-only here',profiles=results)
(p/'independent-metadata.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta,indent=2))
