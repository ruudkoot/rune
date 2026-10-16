from pathlib import Path
import subprocess,json,resource
p=Path(__file__).parent;up=Path('/home/ruud/reference/ghc/nofib/spectral/sorting')
subprocess.run(['ghc','-O2','-i'+str(up),'-outputdir',str(p/'build'),'-o',str(p/'original'),str(up/'Main.hs')],check=True,stdout=(p/'build.log').open('w'),stderr=subprocess.STDOUT)
meta=[]
with(p/'reference.log').open('w')as log:
 for profile,n,file in [('smoke',1,'Main.hs'),('normal',600,'Sort.hs'),('large',3000,'Sort.hs')]:
  def limits():resource.setrlimit(resource.RLIMIT_AS,(4*1024**3,4*1024**3))
  result=subprocess.run([str(p/'original'),str(n),str(up/file)],capture_output=True,check=True,timeout=600,preexec_fn=limits)
  (p/(profile+'.stdout')).write_bytes(result.stdout)
  text=(up/file).read_text();lines=text.splitlines();ordered=sorted(lines);output=''.join(line+'\n'for line in ordered);h=0
  for c in output:h=(ord(c)+h*31)&((1<<64)-1)
  if h>=1<<63:h-=1<<64
  assert result.stdout==(str(h)+'\n').encode()*n
  (p/(profile+'-sorted.txt')).write_text(output)
  meta.append({'profile':profile,'repetitions':n,'source_file':file,'lines':len(ordered),'hash':str(h),'sum':str(h*n)})
  print('PASS original eight-sort pipeline and independent Unicode sorting',profile,n,len(ordered),h,file=log,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
