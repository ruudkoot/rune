from pathlib import Path
import math,re
root=Path.cwd();s=Path('/home/ruud/reference/ghc/nofib/shootout/n-body/Main.hs').read_text();a=s.index('    [0, 0, 0,');b=s.index('    ]',a)
raw=eval(s[a:b+5],{'__builtins__':{}},{'dp':365.24,'solar_mass':4*math.pi**2})
initial=[raw[i:i+7]for i in range(0,35,7)]
def simulate(n):
 bodies=[b[:]for b in initial]
 for k in range(3):bodies[0][k+3]=-sum(b[6]*b[k+3]for b in bodies[1:])/bodies[0][6]
 def energy():
  kinetic=sum(.5*b[6]*sum(v*v for v in b[3:6])for b in bodies)
  potential=sum(bodies[i][6]*bodies[j][6]/math.sqrt(sum((bodies[i][k]-bodies[j][k])**2 for k in range(3)))for i in range(5)for j in range(i+1,5))
  return kinetic-potential
 before=energy()
 for _ in range(n):
  for i in range(5):
   for j in range(i+1,5):
    d=[bodies[i][k]-bodies[j][k]for k in range(3)];r2=sum(x*x for x in d);factor=.01/(r2*math.sqrt(r2))
    for k in range(3):
     bodies[i][k+3]-=bodies[j][6]*factor*d[k];bodies[j][k+3]+=bodies[i][6]*factor*d[k]
  for body in bodies:
   for k in range(3):body[k]+=.01*body[k+3]
 return [before,energy()]+[x for b in bodies for x in b]
for profile,n in [('smoke',10),('normal',10000),('large',500000)]:
 expected=[float(x)for x in (root/'examples/benchmarks/n-body/expected'/f'{profile}.txt').read_text().split()];actual=simulate(n);errors=[abs(a-b)for a,b in zip(actual,expected)]
 assert all(math.isfinite(a)and abs(a-b)<=(2e-8 if profile=="large" else 2e-10)+2e-10*abs(b)for a,b in zip(actual,expected)),(profile,max(errors))
 print(profile,n,'max_abs_error',max(errors),flush=True)
