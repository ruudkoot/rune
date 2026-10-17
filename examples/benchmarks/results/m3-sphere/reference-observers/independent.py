from pathlib import Path
import math,json
p=Path(__file__).resolve().parent
EPS=1e-6;BACKGROUND=(.078,.361,.753);FROM=(2.1,1.3,1.7)
BALLS=[((0.,0.,0.),.5),((.272166,.272166,.544331),.166667),
 ((.643951,.172546,0.),.166667),((.172546,.643951,0.),.166667),
 ((-.371785,.0996195,.544331),.166667),((-.471405,.471405,0.),.166667),
 ((-.643951,-.172546,0.),.166667),((.0996195,-.371785,.544331),.166667),
 ((-.172546,-.643951,0.),.166667),((.471405,-.471405,0.),.166667)]
LIGHTS=[(4.,3.,2.),(1.,-4.,4.),(-3.,1.,5.)]
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,b):return tuple(x*y for x,y in zip(a,b))
def scale(a,k):return tuple(k*x for x in a)
def dot(a,b):return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def unit(a):return scale(a,1/math.sqrt(dot(a,a)))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def trace(pos,dir):
 best=None
 for center,radius in BALLS:
  m=sub(pos,center);bm=dot(m,dir);disc=bm*bm-dot(m,m)+radius*radius
  if disc<0:continue
  root=math.sqrt(disc);lo=-bm-root;hi=-bm+root
  distance=lo if lo>=0 else hi
  if distance<0:continue
  if best is None or distance<best[0]:best=(distance,center,radius)
 return best
def cutoff(v):return all(x<EPS for x in v) # Source uses signed comparisons.
def shade(pos,dir,hit,contrib):
 distance,center,radius=hit;point=add(pos,scale(dir,distance))
 normal=scale(sub(point,center),1/radius);reflection=add(dir,scale(normal,-2*dot(dir,normal)))
 contributions=[]
 for light in LIGHTS:
  ld=unit(sub(light,point))
  # The source shadow test does not limit intersections to the light distance.
  if trace(add(point,scale(ld,EPS)),ld):contributions.append((0.,0.,0.));continue
  cosine=dot(ld,normal)
  diffuse=scale((.5,.45,.35),abs(cosine))
  if cosine<=0:
   alpha=-dot(reflection,ld);spec=scale((1.,1.,1.),0. if alpha<=0 else alpha**3.)
  else:
   alpha=dot(reflection,ld);spec=scale((.8,.8,.8),0. if alpha<=0 else alpha**3.)
  contributions.append(mul(add(diffuse,spec),(.288675,.288675,.288675)))
 light=(0.,0.,0.)
 for v in reversed(contributions):light=add(v,light)
 result=add((.035,.0325,.025),light)
 intensity=scale((.8,.8,.8),.5);newcontrib=mul(intensity,contrib)
 if cutoff(intensity)or cutoff(newcontrib):return result
 near=add(point,scale(reflection,EPS));next_hit=trace(near,reflection)
 next_color=shade(near,reflection,next_hit,newcontrib)if next_hit else BACKGROUND
 return add(result,mul(next_color,intensity))
def image(size):
 initial=sub((0.,0.,0.),FROM);distance=math.sqrt(dot(initial,initial));direction=unit(initial)
 i=unit(cross(direction,(0.,0.,1.)));j=unit(cross(i,direction))
 magnitude=2*distance*math.tan((45/2)*math.pi/180)/size
 sx=scale(i,magnitude);sy=scale(j,magnitude)
 first=sub(initial,add(scale(sx,.5*size),scale(sy,.5*size)))
 for i in range(size):
  for j in range(size):
   d=unit(add(add(first,scale(sx,float(i))),scale(sy,float(j))));hit=trace(FROM,d)
   yield i,j,shade(FROM,d,hit,(1.,1.,1.))if hit else BACKGROUND
records=[]
for name,size in [('smoke',30),('normal',100),('large',250)]:
 lines=(p/(name+'.pixels')).read_text().splitlines();maximum=0.;checked=0
 for(i,j,actual),row in zip(image(size),lines):
  tokens=row.split();assert[i,j]==list(map(int,tokens[:2]));wanted=list(map(float,tokens[2:5]));quantized=list(map(int,tokens[5:]))
  assert all(abs(a-b)<=1e-9+1e-9*abs(b)for a,b in zip(actual,wanted))
  assert[round(255*x)for x in actual]==quantized
  maximum=max(maximum,max(abs(a-b)for a,b in zip(actual,wanted)));checked+=1
 assert checked==size*size==len(lines)
 records.append(dict(profile=name,pixels=checked,max_absolute_difference=maximum,all_quantized_components_agree=True));print(records[-1],flush=True)
(p/'independent-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
