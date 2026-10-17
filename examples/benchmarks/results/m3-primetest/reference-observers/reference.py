from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/primetest';d=p/'source';d.mkdir(exist_ok=True)
for file in up.iterdir():
 if file.is_file():shutil.copyfile(file,d/file.name)
with(d/'original-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
rows=[]
for profile,filename in [('smoke','primetest.faststdin'),('normal','primetest.stdin'),('large','primetest.slowstdin')]:
 raw=subprocess.check_output([str(d/'original'),'+RTS','-M1g','-RTS'],cwd=d,input=(d/filename).read_bytes(),timeout=180)
 fixture=filename.replace('stdin','stdout');assert raw==(d/fixture).read_bytes();(p/(profile+'.stdout')).write_bytes(raw)
 rows.append(dict(profile=profile,input=filename,lines=len((d/filename).read_text().splitlines()),bytes=len(raw)));print(rows[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),nofib_revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',profiles=rows),indent=2)+'\n')
