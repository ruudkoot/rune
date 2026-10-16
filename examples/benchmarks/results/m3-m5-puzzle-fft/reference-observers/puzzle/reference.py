from pathlib import Path
import hashlib,json,resource,subprocess,time
ref=Path(__file__).resolve().parent
source=(ref/'Main.hs').read_text();assert source.count('module Main(main) where')==1
(ref/'Kernel.hs').write_text(source.replace('module Main(main) where','module Kernel where'))
for kind,file in [('original','Main.hs'),('observer','Observer.hs')]:
    with(ref/(kind+'-build.log')).open('w')as log:
        subprocess.run(['/usr/bin/ghc','-O2','-i'+str(ref),'-outputdir',str(ref/('ghc-'+kind)),'-o',str(ref/kind),str(ref/file)],check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():
    resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
records=[]
for n in [2,16,80]:
    start=time.monotonic();result=subprocess.run([str(ref/'original'),str(n)],capture_output=True,timeout=120,preexec_fn=bounded)
    assert result.returncode==0 and not result.stdout,(n,result.stderr)
    (ref/f'original-{n}.stdout').write_bytes(result.stdout)
    (ref/f'original-{n}.stderr').write_bytes(result.stderr)
    records.append({'repetitions':n,'seconds':time.monotonic()-start,'stdout_bytes':len(result.stdout)})
with(ref/'observer.log').open('w')as log:
    subprocess.run([str(ref/'observer'),str(ref/'original')],check=True,timeout=120,preexec_fn=bounded,stdout=log,stderr=subprocess.STDOUT)
with(ref/'independent.log').open('w')as log:
    subprocess.run(['python3',str(ref/'independent.py')],check=True,stdout=log,stderr=subprocess.STDOUT)
(ref/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
(ref/'reference-identities.json').write_text(json.dumps({'ghc':subprocess.check_output(['/usr/bin/ghc','--numeric-version'],text=True).strip(),'options':['-O2'],'upstream_revision':'b7391df4540ac8b11b35e1b2e2c15819b5171798','source_path':'spectral/puzzle','observer_change':'export-only module rename and separate observers; kernel unchanged','sha256':{name:hashlib.sha256((ref/name).read_bytes()).hexdigest()for name in ['Main.hs','Makefile','Kernel.hs','Observer.hs','independent.py']}},indent=2)+'\n')
print('PASS all three original runs, exhaustive histogram, ordered minima and independent shortest path')
