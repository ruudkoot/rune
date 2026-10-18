from pathlib import Path
import subprocess,json,hashlib,datetime,concurrent.futures,threading
p=Path(__file__).resolve().parent
names=['nucleic2-lazy','nucleic2-strict','nucleic2-shared-lazy','nucleic2-shared-strict']
subject={str(f):hashlib.sha256(f.read_bytes()).hexdigest()for f in Path('examples/benchmarks/shared').glob('nucleic2-*.sml')}
(p/'count-subject.json').write_text(json.dumps(dict(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),sources=subject,orchestration='two independent count-only jobs; no OS timing is a headline sample'),indent=2)+'\n')
records=[];lock=threading.Lock()
def one(name):
 cmd=['python3','tests/out/benchmarks/cryptarithm1-originals/count-guard.py','--rss-kib','2097152','--available-kib','8388608','--log',str(p/('count-'+name+'-guard.log')),'--record',str(p/('count-'+name+'.json')),'--','make','bench-count','BENCH_PROFILE=normal','BENCH_FILTER=='+name]
 with(p/('count-'+name+'.log')).open('w')as out:r=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT)
 record=dict(name=name,exit=r.returncode)
 with lock:
  records.append(record);(p/'count-exits.json').write_text(json.dumps(sorted(records,key=lambda r:r['name']),indent=2)+'\n')
 print(record,flush=True);return record
(p/'count-exits.json').write_text('[]\n')
with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
 results=list(pool.map(one,names))
raise SystemExit(any(r['exit']for r in results))
