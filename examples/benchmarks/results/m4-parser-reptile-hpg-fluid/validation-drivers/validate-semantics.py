from pathlib import Path
import subprocess,json,time
p=Path(__file__).resolve().parent;records=[]
for family in ['parser','reptile','hpg','fluid']:
 cmd=['sh','tests/benchmarks/check-nofib-'+family+'.sh'];log=p/('semantics-'+family+'.log');start=time.monotonic()
 print('RUN',family,flush=True)
 with log.open('w')as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 records.append(dict(family=family,exit=r.returncode,elapsed_seconds=time.monotonic()-start,log=str(log)))
 (p/'semantic-exits.json').write_text(json.dumps(records,indent=2)+'\n')
 print('DONE',family,r.returncode,flush=True)
raise SystemExit(any(r['exit']for r in records))
