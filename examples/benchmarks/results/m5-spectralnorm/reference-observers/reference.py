from pathlib import Path
import subprocess,resource,math,json
p=Path(__file__).parent;source=Path('tests/out/benchmarks/upstreams/sandmark/benchmarks/benchmarksgame/spectralnorm2.ml').read_text();(p/'norm_observer.ml').write_text(source.replace('"%0.9f\\n"','"%.17g\\n"'))
subprocess.run(['ocamlopt','-O2','-o',str(p/'observer'),str(p/'norm_observer.ml')],check=True)
meta=[]
for profile,n,timeout,memory in [('smoke',8,30,1024**3),('normal',256,600,4*1024**3),('large',5500,3600,8*1024**3)]:
 def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
 result=subprocess.run([str(p/'observer'),str(n)],capture_output=True,check=True,timeout=timeout,preexec_fn=limits);value=float(result.stdout);assert math.isfinite(value)
 if profile!='large':
  a=[[1.0/((i+j)*(i+j+1)//2+i+1)for j in range(n)]for i in range(n)]
  def ata(u):
   w=[math.fsum(x*y for x,y in zip(row,u))for row in a]
   return [math.fsum(a[j][i]*w[j]for j in range(n))for i in range(n)]
  u=[1.0]*n
  for _ in range(10):v=ata(u);u=ata(v)
  oracle=math.sqrt(math.fsum(x*y for x,y in zip(u,v))/math.fsum(x*x for x in v));assert abs(value-oracle)<=2e-12*max(1,abs(value))
 meta.append({'profile':profile,'size':n,'reference':result.stdout.decode().strip(),'timeout':timeout,'memory_bytes':memory})
 print('PASS original spectral norm and available independent fsum reference',profile,n,value,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
