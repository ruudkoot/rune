from pathlib import Path
import subprocess,os,json,time,hashlib,datetime
p=Path(__file__).resolve().parent
sources={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for family in ['parser','reptile','hpg','fluid']for f in Path('examples/benchmarks/shared').glob('nofib-'+family+'-*.sml')}
(p/'serial-subject-fixed.json').write_text(json.dumps(dict(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),sources=sources,mode='one fresh-process serial adapter diagnostic; no headline timing claim'),indent=2)+'\n')
records=[]
for family in ['reptile','hpg','fluid']:
 cmd=['make','bench','BENCH_PROFILE=smoke','BENCH_FILTER='+family+'-','BENCH_CONFIGS=native:mlton,native:smlnj-legacy,native:polyml','BENCH_SAMPLES=1','BENCH_MODE=fresh']
 start=time.monotonic();log=p/('serial-native-fixed-'+family+'.log');print('RUN',family,flush=True)
 with log.open('w')as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 records.append(dict(family=family,command=cmd,exit=r.returncode,elapsed_seconds=time.monotonic()-start,log=str(log)))
 (p/'serial-native-fixed-exits.json').write_text(json.dumps(records,indent=2)+'\n')
 print('DONE',family,r.returncode,flush=True)
raise SystemExit(any(r['exit']for r in records))
