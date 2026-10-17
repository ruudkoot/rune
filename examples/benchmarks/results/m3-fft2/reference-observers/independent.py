# Fourier benchmark by Rex Page, Amoco Production Research, September 1992.
# Independent eager Python model; original source/correspondence retained.
from pathlib import Path
import math,json
p=Path(__file__).resolve().parent
def add(values):
 result=0
 for value in values:result=result+value
 return result
def roots(n):return[complex(math.cos((2*math.pi/n)*k),math.sin((2*math.pi/n)*k))for k in range(n)]
def fast(values,unity):
 if len(values)==1:return values
 if not values:raise ValueError('source ffth has no empty clause')
 even=fast(values[::2],unity[::2]);odd=fast(values[1::2],unity[::2])
 return[even[i%len(even)]+u*odd[i%len(odd)]for i,u in enumerate(unity)]
def factors(n):
 out=[];divisor=2
 while n!=1:
  if n%divisor==0:out.append(divisor);n//=divisor
  else:divisor+=1
 return out
def mixed(fs,values,unity,stride):
 f=fs[0]
 if len(fs)==1:return[add(x*unity[(stride*k*j)%len(unity)]for j,x in enumerate(values))for k in range(f)]
 partial=[]
 for k in range(f):
  result=mixed(fs[1:],values[k::f],unity,stride*f)*f
  partial.append([x*unity[(stride*k*j)%len(unity)]for j,x in enumerate(result)])
 return[add(row[j]for row in partial)for j in range(len(values))]
def forward(values):
 n=len(values);u=[x.conjugate()for x in roots(n)]
 return[x*(1/n)for x in mixed(factors(n),values,u,1)]
def inverse(values):return mixed(factors(len(values)),values,roots(len(values)),1)
def distance(a,b):return math.sqrt(add(math.hypot((x-y).real,(x-y).imag)**2 for x,y in zip(a,b)))
def cosine(values):
 n=len(values)
 return[add(x*math.cos(k*((2*math.pi/n)*j))for j,x in enumerate(values))for k in range(n)]
def metrics(n):
 xs=list(map(float,range(n)));zs=list(map(complex,xs));u=roots(n)
 a=[x*(1/n)for x in fast(zs,[z.conjugate()for z in u])]
 b=fast(a,u)
 return[distance(zs,b),distance(zs,inverse(forward(zs))),add(cosine(xs))]
rows=[]
cache={}
for profile,base in[('smoke',70),('normal',245),('large',490)]:
 expected=[float(line.split(' = ')[1])for line in(p/(profile+'.values')).read_text().splitlines()]
 errors=[0.,0.,0.]
 for i in range(1,101):
  length=math.floor(base+i/15+.5)
  if length not in cache:cache[length]=metrics(length)
  observed=cache[length];wanted=expected[(i-1)*3:i*3]
  errors=[max(e,abs(a-b))for e,a,b in zip(errors,observed,wanted)]
  assert abs(observed[0]-wanted[0])<=1e-9+1e-10*abs(wanted[0]),(profile,i,observed,wanted)
  assert observed[1]<1e-7 and abs(observed[2])<1e-5,(profile,i,observed)
 record=dict(profile=profile,base=base,rows=100,distinct_lengths=sorted({math.floor(base+i/15+.5)for i in range(1,101)}),maximum_source_difference=errors)
 rows.append(record);print(record,flush=True)
(p/'independent-metadata.json').write_text(json.dumps(dict(scope='Independent eager list/slice and cyclic-index transform model with hypot distance; unique-size caching exists only in this reference model, not benchmark execution',profiles=rows),indent=2)+'\n')
