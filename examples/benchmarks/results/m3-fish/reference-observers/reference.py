from pathlib import Path
import ast,subprocess,resource,json
p=Path(__file__).parent;up=Path('/home/ruud/reference/ghc/nofib/spectral/fish/Main.hs');source=up.read_text()
tiles={}
for name,nextname in [('p_tile','q_tile'),('q_tile','r_tile'),('r_tile','s_tile'),('s_tile','type Line_segment')]:tiles[name]=ast.literal_eval(source.split(name+' =',1)[1].split(nextname,1)[0].strip())
def add(a,b):return a[0]+b[0],a[1]+b[1]
def neg(a):return -a[0],-a[1]
def scale(v,a,b):return v[0]*a//b,v[1]*a//b
def grid(data,a,b,c):
 def point(x,y):return add(add(a,scale(b,x,16)),scale(c,y,16))
 return [point(x,y)+point(u,v)for x,y,u,v in data]
def tile(data):return lambda a,b,c:grid(data,a,b,c)
def empty(a,b,c):return []
def rot(pic):return lambda a,b,c:pic(add(a,b),c,neg(b))
def beside(m,n,pic,q):return lambda a,b,c:pic(a,scale(b,m,m+n),c)+q(add(a,scale(b,m,m+n)),scale(b,n,n+m),c)
def above(m,n,pic,q):return lambda a,b,c:pic(add(a,scale(c,n,m+n)),b,scale(c,m,n+m))+q(a,b,scale(c,n,m+n))
def quartet(a,b,c,d):return above(1,1,beside(1,1,a,b),beside(1,1,c,d))
def cycle(pic):return quartet(pic,rot(rot(rot(pic))),rot(pic),rot(rot(pic)))
pt,qt,rt,st=(tile(tiles[name])for name in ['p_tile','q_tile','r_tile','s_tile']);t=quartet(pt,qt,rt,st);u=cycle(rot(qt));side1=quartet(empty,empty,rot(t),t);side2=quartet(side1,side1,rot(t),t);corner1=quartet(empty,empty,empty,u);corner2=quartet(corner1,side1,rot(side1),u);picture=cycle(quartet(corner2,side2,rot(side2),rot(t)))
(p/'Kernel.hs').write_text(source.replace('module Main (main) where','module Kernel where'))
(p/'Observer.hs').write_text('module Main where\nimport qualified Kernel as K\nimport System.Environment\nmain=getArgs >>= \\[size] -> putStr(K.fmt(K.pseudolimit (0,0) (read size,0) (0,read size)))\n')
subprocess.run(['ghc','-O2','-outputdir',str(p/'build'),'-o',str(p/'original'),str(up)],check=True,stdout=(p/'build.log').open('w'),stderr=subprocess.STDOUT)
subprocess.run(['ghc','-O2','-i'+str(p),'-outputdir',str(p/'observer-build'),'-o',str(p/'observer'),str(p/'Observer.hs')],check=True,stdout=(p/'observer-build.log').open('w'),stderr=subprocess.STDOUT)
def limits():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
meta=[]
with(p/'reference.log').open('w')as log:
 for size in [255,640,641]:
  segments=picture((0,0),(size,0),(0,size));expected=('[\n'+',\n'.join('('+','.join(map(str,row))+')'for row in segments)+']').encode()
  result=subprocess.run([str(p/'observer'),str(size)],capture_output=True,check=True,timeout=60,preexec_fn=limits);assert result.stdout==expected
  (p/(str(size)+'.txt')).write_bytes(expected);(p/(str(size)+'.segments')).write_text(''.join(' '.join(map(str,row))+'\n'for row in segments));meta.append({'size':size,'segments':len(segments),'formatted_length':len(expected)})
  print('PASS original and independent integer affine model',size,len(segments),len(expected),file=log,flush=True)
 for profile,n in [('smoke',1),('normal',300),('large',1500)]:
  result=subprocess.run([str(p/'original'),str(n)],capture_output=True,check=True,timeout=600,preexec_fn=limits);assert not result.stdout
  print('PASS original length-forced invocation',profile,n,file=log,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
