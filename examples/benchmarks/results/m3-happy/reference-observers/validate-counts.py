from pathlib import Path
import subprocess,json,hashlib,datetime
p=Path(__file__).resolve().parent
subject={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for f in Path('examples/benchmarks/shared').glob('happy-*.sml')}
(p/'count-subject.json').write_text(json.dumps(dict(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),sources=subject),indent=2)+'\n')
records=[]
(p/'count-exits.json').write_text('[]\n')
for name in ['happy-lazy','happy-strict']:
 cmd=['python3','tests/out/benchmarks/cryptarithm1-originals/count-guard.py','--rss-kib','2097152','--available-kib','8388608','--log',str(p/('count-'+name+'-guard.log')),'--record',str(p/('count-'+name+'.json')),'--','make','bench-count','BENCH_PROFILE=normal','BENCH_FILTER=='+name]
 record=p/('count-'+name+'.json')
 if record.exists():record.unlink()
 with(p/('count-'+name+'.log')).open('w')as out:
  r=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT)
 records.append(dict(name=name,exit=r.returncode))
 (p/'count-exits.json').write_text(json.dumps(records,indent=2)+'\n')
 print(records[-1],flush=True)
raise SystemExit(any(r['exit']for r in records))
