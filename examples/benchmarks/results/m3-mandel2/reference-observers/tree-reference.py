from pathlib import Path
import subprocess,resource,struct,functools,json
r=Path(__file__).resolve().parent
for source,exe in [('Main.hs','original'),('TreeObserver.hs','tree-observer')]:
 with(r/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,source,'Kernel.hs','NofibUtils.hs']if source!='Main.hs'else['ghc','-O2','-fforce-recomp','-o',exe,source,'NofibUtils.hs'],cwd=r,check=True,stdout=log,stderr=subprocess.STDOUT)
def limit():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(180,180))
for reps in [2,20,100]:
 result=subprocess.run([str(r/'original'),str(reps)],capture_output=True,timeout=195,preexec_fn=limit);assert result.returncode==0 and result.stdout==b'',(reps,result.stderr)
 print('PASS original finite forcing, 200x100 bounds, repetitions',reps,flush=True)
def f(x):return struct.unpack('!f',struct.pack('!f',x))[0]
dp=f(f(.75-f(-2.25))/f(199));dq=f(f(1.5-f(-1.5))/f(199));visited=set()
@functools.lru_cache(None)
def point(x,y):
 visited.add((x,y));p=f(f(-2.25)+f(f(x)*dp));q=f(f(-1.5)+f(f(y)*dq));a=f(0);b=f(0)
 for k in range(1,26):
  nx=f(f(f(a*a)-f(b*b))+p);ny=f(f(f(f(2)*a)*b)+q);radius=f(f(nx*nx)+f(ny*ny))
  if radius>f(20):return k
  a,b=nx,ny
 return 0

def perimeter(x1,y1,x2,y2):
 c=point(x1,y1)
 if x1==x2 and y1==y2:return c
 for x,y in [(x2,y1),(x2,y2),(x1,y2)]:
  if point(x,y)!=c:return -1
 for x,y,dx,dy in [(x1+1,y1,1,0),(x2,y1+1,0,1),(x2-1,y2,-1,0),(x1,y2-1,0,-1)]:
  for step in range(1000):
   finished=x>=x2 if dx==1 else y<=y2 if dy==1 else x<=x1 if dx==-1 else y>=y1
   if finished:break
   if point(x,y)!=c:return -1
   x+=dx;y+=dy
  else:raise AssertionError('source line did not terminate')
 return c

def build(x1,y1,x2,y2):
 c=perimeter(x1,y1,x2,y2);bounds=f'{x1} {y1} {x2} {y2}'
 if c!=-1:return [f'L {bounds} {c}\n']
 if x2-x1>=y2-y1:
  middle=(x1+x2)//2
  return [f'NS {bounds}\n']+build(x1,y1,middle,y2)+build(middle+1,y1,x2,y2)
 middle=(y1+y2)//2
 return [f'EW {bounds}\n']+build(x1,y1,x2,middle)+build(x1,middle+1,x2,y2)
meta=[]
for width in [1,2,3,8,16,64,200]:
 visited.clear();point.cache_clear();expected=''.join(build(0,0,width,width//2));raw=subprocess.check_output([str(r/'tree-observer'),str(width)],timeout=195,preexec_fn=limit).decode();assert raw==expected,width
 (r/(str(width)+'.tree')).write_text(raw);outside=sorted((x,y)for x,y in visited if y<0 or y>width//2)
 meta.append(dict(bounds=[0,0,width,width//2],coordinate_scale=200,nodes=len(raw.splitlines()),outside_point_requests=outside,comparison='complete source tree/preorder/colours and independent binary32 perimeter model; preserve direction conditions'))
 print('PASS complete tree source/independent',width,len(raw.splitlines()),'nodes;',len(outside),'outside points',flush=True)
(r/'tree-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
