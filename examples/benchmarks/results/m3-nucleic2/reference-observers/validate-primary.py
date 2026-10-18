from pathlib import Path
import subprocess,os,json,hashlib,datetime
p=Path(__file__).resolve().parent
records=[]
subject={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for f in Path('examples/benchmarks/shared').glob('nucleic2-*.sml')}
(p/'primary-subject.json').write_text(json.dumps(dict(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),sources=subject),indent=2)+'\n')
# Rune gets both compiler levels; native hosts run once with host-default flags.
for level,configs in [('O0','rune,rune:new,rune:jit,rune:opt'),('O2','rune,rune:new,rune:jit,rune:opt,hosts')]:
 for profile in ['smoke','normal']:
  cmd=['make','bench-check','BENCH_FILTER=nucleic2-','BENCH_PROFILE='+profile,'BENCH_CONFIGS='+configs]
  env=dict(os.environ,RUNE_BENCH_COMPILE_OPTIONS='-'+level)
  log=p/('primary-'+level+'-'+profile+'.log')
  print('RUN',level,profile,configs,flush=True)
  with log.open('w')as out:r=subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT)
  records.append(dict(level=level,profile=profile,configs=configs,exit=r.returncode,log=str(log)))
  (p/'primary-exits.json').write_text(json.dumps(records,indent=2)+'\n')
  print('DONE',level,profile,r.returncode,flush=True)
raise SystemExit(any(r['exit']for r in records))
