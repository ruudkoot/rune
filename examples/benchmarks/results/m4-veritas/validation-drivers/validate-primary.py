from pathlib import Path
import subprocess,os,json,time
p=Path(__file__).resolve().parent;records=[]
for level,configs in [('O0','rune,rune:new,rune:jit,rune:opt'),('O2','rune,rune:new,rune:jit,rune:opt,hosts')]:
 for profile in ['smoke','normal']:
  for family in ['veritas']:
   cmd=['make','bench-check','BENCH_PROFILE='+profile,'BENCH_FILTER='+family+'-','BENCH_CONFIGS='+configs]
   log=p/('primary-'+level+'-'+profile+'-'+family+'.log');start=time.monotonic()
   print('RUN',level,profile,family,flush=True)
   with log.open('w')as f:r=subprocess.run(cmd,env=dict(os.environ,RUNE_BENCH_COMPILE_OPTIONS='-'+level),stdout=f,stderr=subprocess.STDOUT)
   records.append(dict(level=level,profile=profile,family=family,configs=configs,exit=r.returncode,elapsed_seconds=time.monotonic()-start,log=str(log)))
   (p/'primary-exits.json').write_text(json.dumps(records,indent=2)+'\n')
   print('DONE',level,profile,family,r.returncode,flush=True)
raise SystemExit(any(r['exit']for r in records))
