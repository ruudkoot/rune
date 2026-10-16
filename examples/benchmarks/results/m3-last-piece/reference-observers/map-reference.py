from pathlib import Path
import subprocess
r=Path(__file__).resolve().parent
with(r/'map-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','map-observer','MapObserver.hs'],cwd=r,stdout=log,stderr=subprocess.STDOUT,check=True)
for name in ['ascending','descending','zigzag','permuted']:
 raw=subprocess.check_output([str(r/'map-observer'),name],text=True);assert len(raw.splitlines())==64;(r/('map-'+name+'.expected')).write_text(raw);print('Recorded original containers0.6.7 every-prefix shape',name,flush=True)
