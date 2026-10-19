from pathlib import Path
import subprocess,json,concurrent.futures
p=Path(__file__).resolve().parent
def one(name):
 cmd=['python3','tests/out/benchmarks/cryptarithm1-originals/count-guard.py','--rss-kib','2097152','--available-kib','8388608','--log',str(p/('count-'+name+'-guard.log')),'--record',str(p/('count-'+name+'.json')),'--','make','bench-count','BENCH_PROFILE=normal','BENCH_FILTER=='+name]
 print('RUN',name,flush=True)
 with(p/('count-'+name+'.log')).open('w')as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 print('DONE',name,r.returncode,flush=True)
 return dict(benchmark=name,exit=r.returncode)
names=[f+'-'+v for f in ['veritas']for v in ['lazy','strict']]
records=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
 futures=[pool.submit(one,n)for n in names]
 for future in concurrent.futures.as_completed(futures):
  records.append(future.result());(p/'count-exits.json').write_text(json.dumps(records,indent=2)+'\n')
raise SystemExit(any(r['exit']for r in records))
