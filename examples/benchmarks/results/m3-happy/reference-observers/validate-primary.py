from pathlib import Path
import subprocess,os,json
p=Path(__file__).resolve().parent
records=[]
for level in ['O0','O2']:
 for profile in ['smoke','normal']:
  cmd=['make','bench-check','BENCH_FILTER=happy-','BENCH_PROFILE='+profile,'BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt,hosts']
  env=dict(os.environ,RUNE_BENCH_COMPILE_OPTIONS='-'+level,JOBS='3')
  log=p/('primary-'+level+'-'+profile+'.log')
  print('RUN',level,profile,flush=True)
  with log.open('w')as out:r=subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT)
  records.append(dict(level=level,profile=profile,exit=r.returncode,log=str(log)))
  (p/'primary-exits.json').write_text(json.dumps(records,indent=2)+'\n')
  print('DONE',level,profile,r.returncode,flush=True)
raise SystemExit(any(r['exit']for r in records))
