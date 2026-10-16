from pathlib import Path
import subprocess,ast,json
r=Path(__file__).resolve().parent
with(r/'edge-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','edge-observer','EdgeObserver.hs'],cwd=r,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(r/'edge-observer')],text=True);(r/'edge-observer.output').write_text(raw);cases=dict(ast.literal_eval(line)for line in raw.splitlines());(r/'edge-metadata.json').write_text(json.dumps(cases,indent=2)+'\n')
for name,text in cases.items():(r/('edge-'+name+'.session')).write_text(text)
print('Recorded six complete original state/conjugation/punctuation edge sessions')
