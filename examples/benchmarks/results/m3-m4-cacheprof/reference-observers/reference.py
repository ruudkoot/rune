from pathlib import Path
import shutil,subprocess,resource,time,json,hashlib
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib'
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for family in ['gc','real']:
 d=p/family/'source';shutil.copytree(up/family/'cacheprof',d,dirs_exist_ok=True)
 with(p/(family+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
 for profile,file in [('source-fast','cacheprof.faststdin'),('normal','cacheprof.stdin'),('source-slow','cacheprof.slowstdin')]:
  if not(d/file).exists():continue
  start=time.monotonic();result=subprocess.run([str(d/'original')],cwd=d,input=(d/file).read_bytes(),capture_output=True,timeout=120,preexec_fn=cap,check=True)
  (p/family/(profile+'.stdout')).write_bytes(result.stdout);(p/family/(profile+'.stderr')).write_bytes(result.stderr)
  if family=='gc':print('PINNED FIXTURE AGREEMENT',result.stdout==(d/'cacheprof.stdout').read_bytes(),'fixture bytes',len((d/'cacheprof.stdout').read_bytes()),flush=True)
  else:assert result.stdout==b''
  records.append(dict(family=family,profile=profile,bytes=len(result.stdout),sha256=hashlib.sha256(result.stdout).hexdigest(),seconds=time.monotonic()-start))
  print(records[-1],flush=True)
# Export all original functions for read-only observations; kernel unchanged.
d=p/'observer-source';shutil.copytree(p/'real/source',d,ignore=shutil.ignore_patterns('original','*.hi','*.o'),dirs_exist_ok=True)
text=(d/'Main.hs').read_text().replace('module Main ( main ) where','module CacheMain where')
(d/'CacheMain.hs').write_text(text)
(d/'Observer.hs').write_text('module Main where\nimport CacheMain (doFile)\nmain=getContents >>= doFile 2 [] >>= putStr\n')
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
for profile,file in [('source-fast','cacheprof.faststdin'),('normal','cacheprof.stdin'),('source-slow','cacheprof.slowstdin')]:
 result=subprocess.run([str(d/'observer')],input=(p/'real/source'/file).read_bytes(),capture_output=True,timeout=120,preexec_fn=cap,check=True)
 (p/(profile+'.annotated')).write_bytes(result.stdout);(p/(profile+'.observer-stderr')).write_bytes(result.stderr)
 print('OBSERVED',profile,len(result.stdout),flush=True)
aux=(p/'gc/source/cacheprof_hooks2_x86.s').read_bytes()
assert(p/'gc/normal.stdout').read_bytes()==(p/'normal.annotated').read_bytes()+aux
(p/'reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
