from pathlib import Path
import subprocess,time,json,os
p=Path(__file__).resolve().parent
cmd=['make','JOBS=4','bench-smoke']
started=time.monotonic()
with(p/'smoke.log').open('w')as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,DEBUGINFOD_URLS=''))
(p/'smoke-exit.json').write_text(json.dumps({'command':cmd,'exit':r.returncode,'elapsed_seconds':time.monotonic()-started},indent=2)+'\n')
raise SystemExit(r.returncode)
