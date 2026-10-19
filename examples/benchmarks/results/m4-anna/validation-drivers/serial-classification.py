from pathlib import Path
import subprocess,json,time,os
p=Path(__file__).resolve().parent
cmd=['make','bench','BENCH_PROFILE=smoke','BENCH_FILTER=anna-','BENCH_CONFIGS=native:smlnj-legacy','BENCH_MODE=fresh','BENCH_SAMPLES=1']
started=time.monotonic()
with(p/'serial-native-classification.log').open('w')as f:r=subprocess.run(cmd,env=dict(os.environ,RUNE_BENCH_COMPILE_OPTIONS='-O2'),stdout=f,stderr=subprocess.STDOUT)
(p/'serial-classification-exit.json').write_text(json.dumps(dict(command=cmd,exit=r.returncode,elapsed_seconds=time.monotonic()-started),indent=2)+'\n')
raise SystemExit(r.returncode)
