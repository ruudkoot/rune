from pathlib import Path
import subprocess,resource,json,hashlib
ref=Path(__file__).resolve().parent
for stem,source in [('original','smallpt.hs'),('observer','Observer.hs')]:
 with(ref/(stem+'-build.log')).open('w')as log:subprocess.run(['/usr/bin/ghc','-O2','-i'+str(ref),'-outputdir',str(ref/('ghc-'+stem)),'-o',str(ref/stem),str(ref/source)],check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3));resource.setrlimit(resource.RLIMIT_CPU,(180,180))
records=[]
for samples,fixture in [(1,'smallpt.stdout'),(6,'smallpt.slowstdout')]:
 r=subprocess.run([str(ref/'original'),'hash',str(samples)],capture_output=True,timeout=195,preexec_fn=bounded);assert r.returncode==0,r.stderr
 expected=(ref/fixture).read_bytes();assert expected.endswith(b'\n')and r.stdout==expected[:-1]
 records.append({'samples':samples,'fixture':fixture,'raw_stdout':r.stdout.decode(),'comparison':'fixture has one terminalLF absent from source hPutStr output'});print('PASS pinned original hash value/finalLF adaptation',samples,flush=True)
for width,height,samples in [(16,12,1),(64,48,1),(512,384,1),(512,384,6)]:
 r=subprocess.run([str(ref/'observer'),str(width),str(height),str(samples)],capture_output=True,timeout=195,preexec_fn=bounded);assert r.returncode==0,r.stderr
 assert r.stdout==(ref/f'{width}-{height}-{samples}.rgb').read_bytes()
 print('PASS strict boxed adapter unchanged full scene',width,height,samples,flush=True)
(ref/'strict-adapter-metadata.json').write_text(json.dumps({'ghc':subprocess.check_output(['/usr/bin/ghc','--numeric-version'],text=True).strip(),'adapter':'boxed STRef, strict initialize/write; correctness-only','adapter_sha256':hashlib.sha256((ref/'Data/STRef/Unboxed.hs').read_bytes()).hexdigest(),'pinned_originals':records},indent=2)+'\n')
