from pathlib import Path
import subprocess,os,json,time,hashlib
p=Path(__file__).resolve().parent;records=[]
subjects={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for family in ['parser','reptile','hpg','fluid']for f in Path('examples/benchmarks/shared').glob('nofib-'+family+'-*.sml')}
(p/'local-smoke-subject.json').write_text(json.dumps(subjects,indent=2)+'\n')
for family in ['parser','reptile','hpg','fluid']:
 cmd=['make','bench-check','BENCH_PROFILE=smoke','BENCH_FILTER='+family+'-','BENCH_CONFIGS=rune']
 start=time.monotonic();log=p/('local-smoke-'+family+'.log');print('RUN',family,flush=True)
 with log.open('w')as f:r=subprocess.run(cmd,env=dict(os.environ,RUNE_BENCH_COMPILE_OPTIONS='-O0'),stdout=f,stderr=subprocess.STDOUT)
 records.append(dict(family=family,command=cmd,exit=r.returncode,elapsed_seconds=time.monotonic()-start,log=str(log)))
 (p/'local-smoke-exits.json').write_text(json.dumps(records,indent=2)+'\n')
 print('DONE',family,r.returncode,flush=True)
raise SystemExit(any(r['exit']for r in records))
