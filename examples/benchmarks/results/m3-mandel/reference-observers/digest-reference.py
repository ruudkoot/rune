from pathlib import Path
import subprocess,json
r=Path(__file__).resolve().parent;meta=[]
for variant,module in [('new','Mandel.lhs'),('old','MandelOldPort.lhs')]:
 (r/('build-digest-'+variant)).mkdir(exist_ok=True)
 with(r/(variant+'-digest-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-outputdir','build-digest-'+variant,'-o','digest-'+variant,'DigestObserver.hs',module,'PortablePixmap.lhs'],cwd=r,check=True,stdout=log,stderr=subprocess.STDOUT)
 for p in sorted(r.glob(variant+'-*.rgb')):
  w,h,cap=map(int,p.read_text().splitlines()[0].split());raw=subprocess.check_output([str(r/('digest-'+variant)),str(w),str(h),str(cap)],text=True,timeout=180)
  assert raw==p.with_suffix('.digest').read_text(),p
  meta.append(dict(fixture=p.name,digest=raw.strip(),comparison='original Haskell Word64 observer and independent Python rolling digest of complete reviewed RGB'))
  print('PASS original/independent digest',p.stem,flush=True)
(r/'digest-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
