from pathlib import Path
import csv,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/sphere-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/spectral/sphere'
for local,public in [('kernel.sml','nofib-sphere.sml'),('driver.sml','nofib-sphere-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('sphere-')for r in rows)
hashes={'smoke':'1F1C163343ECB0F8','normal':'A7AEE0E71A34BF89','large':format(int((p/'large.stdout').read_text().splitlines()[0])%(2**64),'X')}
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='sphere-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(up,dest/'upstream')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchSphereFn (Bench{policy})
  structure Driver = BenchSphereDriverFn (Kernel)
  val run = Driver.run
end
''')
 for profile,repeats,n in [('smoke',1,30),('normal',100,100),('large',100,250)]:
  shutil.copy(p/(profile+'.pixels'),dest/(profile+'.pixels'))
  (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*n*n} {hashes[profile]}\n')
  sources=['input','lazy','suspend','stream','nofib-sphere','nofib-sphere-driver']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/sphere',f'{repeats} {n} {profile}.pixels',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'numerical,graphs,lists-streams,'+mode,profile+'.pixels','checked-numerical','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/sphere';data.mkdir()
for file in ['smoke.pixels','vectors.reference']:shutil.copy(p/file,data/file)
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/sphere-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-fft2.sh').read_text().replace('fft2','sphere').replace('source transforms, numerical bounds, quoted output and demand checks hold','source image/vector fixtures, numerical checks and demand controls hold')
(root/'tests/benchmarks/check-sphere.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-sphere-parallel.'").replace("{'atom-lazy','atom-strict'}","{'sphere-lazy','sphere-strict'}")
(p/'check-parallel.py').write_text(text)
print('Sphere imported:364 programs/1084 profiles')
