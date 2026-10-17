from pathlib import Path
import struct,math,ast,re,json
p=Path(__file__).resolve().parent
stats=dict(operations=0,subnormal_results=0,nonfinite_results=0)
def f(x):
 y=struct.unpack('<f',struct.pack('<f',x))[0]
 stats['operations']+=1
 if not math.isfinite(y):stats['nonfinite_results']+=1
 elif y and abs(y)<2**-126:stats['subnormal_results']+=1
 return y
def bits(x):return struct.unpack('<I',struct.pack('<f',x))[0]
def add(a,b):return f(a+b)
def sub(a,b):return f(a-b)
def mul(a,b):return f(a*b)
def div(a,b):return f(a/b)
def sqrt(a):return f(math.sqrt(a))
eps=f(.0001)
def eq(a,b):return abs(sub(a,b))<eps
def le(a,b):return sub(a,eps)<b
def lt(a,b):return a<sub(b,eps)
def cmp(a,b):return 0 if eq(a,b)else -1 if le(a,b)else 1
def gt(a,b):return cmp(a,b)>0
def ge(a,b):return cmp(a,b)>=0
def maximum(a,b):return b if le(a,b)else a
def minimum(a,b):return a if le(a,b)else b
def veq(a,b):return len(a)==len(b)and all(eq(x,y)for x,y in zip(a,b))
def va(a,b):return tuple(add(x,y)for x,y in zip(a,b))
def vs(a,b):return tuple(sub(x,y)for x,y in zip(a,b))
def vm(a,b):return (sub(mul(a[1],b[2]),mul(b[1],a[2])),sub(mul(a[2],b[0]),mul(b[2],a[0])),sub(mul(a[0],b[1]),mul(b[0],a[1])))
def scale(c,v):return tuple(mul(c,x)for x in v)
def dot(a,b):
 result=f(0)
 for x,y in zip(a,b):result=add(result,mul(x,y))
 return result
def length(v):return sqrt(dot(v,v))
def norm(v):return scale(div(f(1),length(v)),v)
zero=(f(0),f(0),f(0))
def rotate(view,v):
 if veq(view,zero):return v
 r=norm(view)
 if veq(r,(0.,0.,1.)):return v
 if veq(r,(0.,0.,-1.)):return scale(f(-1),v)
 q=norm(vm((0.,0.,1.),r));s=norm(vm(q,r))
 return tuple(dot(v,row)for row in[s,q,r])
def edge(s,t):return s,vs(t,s)
def end(e):return va(*e)
def proj(v):return v[0],v[1],f(0)
def vertical(e):return veq(vm(e[1],(0.,0.,1.)),zero)
def normal(plate):return norm(vm(plate[0][1],plate[1][1]))
def vertical_plate(plate):return eq(normal(plate)[2],f(0))
def solve(a,b,w):
 det=vm(a,b)[2]
 if eq(det,f(0)):return []
 return [(div(vm(w,b)[2],det),div(vm(a,w)[2],det))]
def altitude(plate,p):
 e1,e2=plate[:2];solutions=solve(e1[1],e2[1],vs(p,e1[0]));assert len(solutions)==1
 a,b=solutions[0]
 return va(va(e1[0],scale(a,e1[1])),scale(b,e2[1]))[2]
def onto(p,e):
 if vertical(e):return veq(proj(p),proj(e[0]))
 v=proj(vs(p,e[0]));w=proj(e[1])
 return veq(vm(v,w),zero)and le(f(0),dot(v,w))and le(dot(v,w),dot(w,w))
def into(p,plate):
 if vertical_plate(plate):return any(onto(p,e)for e in plate)
 z=[vm(vs(p,e[0]),e[1])[2]for e in plate]
 return all(ge(x,f(0))for x in z)or all(le(x,f(0))for x in z)
def cross(a,b):
 result=[]
 for x,y in solve(scale(f(-1),a[1]),b[1],vs(a[0],b[0])):
  if le(f(0),x)and le(x,f(1))and le(f(0),y)and le(y,f(1)):
   result.append((va(a[0],scale(x,a[1])),va(b[0],scale(y,b[1]))))
 return result
def nub(values):
 result=[]
 for x in values:
  if not any(veq(x,y)for y in result):result.append(x)
 return result
def overlap(a,b):return nub([e[0]for e in a if into(e[0],b)]+[x for e in a for k in b for x,y in cross(e,k)])
def above(a,b):
 av,bv=vertical_plate(a),vertical_plate(b)
 if av:
  if bv:return any(gt(x[2],y[2])for x in overlap(a,b)for y in overlap(b,a))
  return any(gt(x[2],altitude(b,x))for x in overlap(a,b))
 if bv:return any(gt(altitude(a,y),y[2])for y in overlap(b,a))
 return any(gt(altitude(a,x),altitude(b,x))for x in nub([proj(x)for x in overlap(a,b)]+[proj(y)for y in overlap(b,a)]))
def clip(e,plate):
 inside_s,inside_t=into(e[0],plate),into(end(e),plate)
 if inside_s and inside_t:return []
 crossings=nub([x for k in plate for x,y in cross(e,k)])
 if not crossings:return[e]
 a,b=crossings[0],crossings[-1]
 if not le(length(vs(e[0],a)),length(vs(e[0],b))):a,b=b,a
 if inside_s and not inside_t:return[edge(b,end(e))]
 if not inside_s and inside_t:return[edge(e[0],a)]
 return[edge(e[0],a),edge(b,end(e))]
def render(file):
 raw=[ast.literal_eval(re.sub(r'\bvec\s*','',line))for line in file.read_text().splitlines()]
 scene=[[rotate((f(2),f(10),f(3)),tuple(map(f,v)))for v in face]for face in raw]
 points=sum(scene,[]);xs=[v[0]for v in points];ys=[v[1]for v in points]
 def reduce(fn,values):
  result=values[0]
  for x in values[1:]:result=fn(result,x)
  return result
 base=(reduce(minimum,xs),reduce(minimum,ys),f(0))
 factor=minimum(div(f(400),maximum(sub(reduce(maximum,xs),base[0]),f(1))),div(f(640),maximum(sub(reduce(maximum,ys),base[1]),f(1))))
 objects=[[edge(a,b)for a,b in zip(face,face[-1:]+face[:-1])]for face in scene]
 memory={}
 def visible(a,b):
  if a==b:return False
  if a>b:
   if(a,b)not in memory:memory[a,b]=above(objects[a],objects[b])
   return memory[a,b]
  return False if visible(b,a)else above(objects[a],objects[b])
 edges=[]
 for bottom,plate in enumerate(objects):
  tops=[top for top in range(len(objects))if visible(top,bottom)]
  result=plate
  for top in reversed(tops):result=[out for e in result for out in clip(e,objects[top])]
  edges+=result
 scaled=[edge(scale(factor,vs(e[0],base)),scale(factor,vs(end(e),base)))for e in edges]
 return scene,base,factor,edges,scaled
results=[]
for profile,file in [('smoke','houses.plate'),('normal','rad.plate'),('large','four.plate')]:
 scene,base,factor,raw,scaled=render(p/'source/runtime_files'/file)
 def rows(edges):return [[bits(x)for x in e[0]+end(e)]for e in edges]
 expected=lambda suffix:[list(map(int,line.split()))for line in(p/(profile+suffix)).read_text().splitlines()]
 assert rows(raw)==expected('.raw-edges'),(profile,'raw',len(raw),len(expected('.raw-edges')))
 assert rows(scaled)==expected('.edges'),(profile,'scaled')
 assert [[bits(x)for x in v]for face in scene for v in face]==expected('.rotated'),(profile,'rotated')
 results.append(dict(profile=profile,polygons=len(scene),visible_edges=len(scaled),complete_bits_match=True))
 print(results[-1],flush=True)
(p/'independent-metadata.json').write_text(json.dumps(dict(scope='Independent eager IEEE binary32 geometry with one mathematical visibility cache; benchmark source retains per-bottom memo construction and explicit lazy demand',profiles=results,arithmetic=stats),indent=2)+'\n')
