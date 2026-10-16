from pathlib import Path
import subprocess,resource,json
r=Path(__file__).resolve().parent;(r/'build-old-main').mkdir(exist_ok=True)
with(r/'old-main-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-outputdir','build-old-main','-o','original-old','Main.hs','MandelOldPort.lhs','PortablePixmap.lhs'],cwd=r,check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
rows=[]
for variant,exe in [('current','original'),('historical-syntax-adapted','original-old')]:
 for size in [25,80,180]:
  args=['-2.0','-2.0','2.0','2.0',str(size),str(size),'75'];result=subprocess.run([str(r/exe)]+args,capture_output=True,timeout=180,preexec_fn=bounded);assert result.returncode==0 and result.stdout==b'',(variant,size,result.stderr)
  rows.append(dict(variant=variant,arguments=args,repetitions=100,exit=result.returncode,stdout_bytes=len(result.stdout),stderr=result.stderr.decode()))
  print('PASS Main NFData forcing',variant,size,'100 repetitions',flush=True)
(r/'original-execution.json').write_text(json.dumps(rows,indent=2)+'\n')
