from pathlib import Path
import subprocess,math,resource,json
r=Path(__file__).resolve().parent
for variant,module in [('new','Mandel.lhs'),('old','MandelOldPort.lhs')]:
 (r/('build-'+variant)).mkdir(exist_ok=True)
 with(r/(variant+'-observer-build.log')).open('w')as log:result=subprocess.run(['ghc','-O2','-fforce-recomp','-outputdir','build-'+variant,'-o','observer-'+variant,'Observer.hs',module,'PortablePixmap.lhs'],cwd=r,stdout=log,stderr=subprocess.STDOUT)
 assert result.returncode==0,variant

def limit():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
def magnitude(x,y):
 k=max(math.frexp(x)[1]if x else 0,math.frexp(y)[1]if y else 0);a=math.ldexp(x,-k);b=math.ldexp(y,-k)
 return math.ldexp(math.sqrt(a*a+b*b),k)
def image(w,h,cap,old):
 pixels=[]
 for t in range(1,h+1):
  for s in range(1,w+1):
   cr=-2.0+(float(s)*4.0)/float(w);ci=-2.0+(float(t)*4.0)/float(h);x=cr;y=ci;count=0
   while count<cap:
    if (x*x+y*y>=4.0)if old else(magnitude(x,y)>2.0):break
    count+=1
    nx=(x*x-y*y)+cr
    ny=(2.0*(x*y)+ci)if old else((x*y+y*x)+ci)
    x,y=nx,ny
   pixels.append((count,cap-count,cap-count))
 return f'{w} {h} {cap}\n'+''.join(' '.join(str(v)for v in pixel)+'\n'for pixel in pixels)
meta=[]
for variant in ['new','old']:
 for w,h,cap in [(4,3,0),(4,3,1),(7,5,75),(25,25,75),(80,80,75),(180,180,75)]:
  raw=subprocess.check_output([str(r/('observer-'+variant)),str(w),str(h),str(cap)],timeout=180,preexec_fn=limit).decode();expected=image(w,h,cap,variant=='old');assert raw==expected,(variant,w,h,cap)
  filename=f'{variant}-{w}-{h}-{cap}.rgb';(r/filename).write_text(raw);meta.append(dict(variant=variant,width=w,height=h,limit=cap,fixture=filename,comparison='every original RGB component and independent binary64 recurrence/scaled norm'))
  print('PASS original/independent every RGB',variant,w,h,cap,flush=True)
(r/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
