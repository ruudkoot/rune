from pathlib import Path
import subprocess,json,time
p=Path(__file__).resolve().parent;cmd=['sh','tests/benchmarks/check-nofib-anna.sh'];started=time.monotonic()
with(p/'semantic-matrix.log').open('w')as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
(p/'semantic-exit.json').write_text(json.dumps(dict(command=cmd,exit=r.returncode,elapsed_seconds=time.monotonic()-started),indent=2)+'\n')
raise SystemExit(r.returncode)
