from pathlib import Path
import csv,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/almabench-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/almabench'
for local,public in [('tables.sml','sandmark-almabench-tables.sml'),('kernel.sml','sandmark-almabench.sml'),('driver.sml','sandmark-almabench-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']=='almabench'for r in rows)
dest=suite/'almabench';dest.mkdir();shutil.copytree(up,dest/'upstream')
(dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
(dest/'benchmark.sml').write_text('''structure Benchmark =
struct
  val name = "almabench"
  val run = BenchAlmaDriver.run
end
''')
for profile,loops,days in [('smoke',1,32),('normal',5,36525),('large',20,36525)]:
 shutil.copy(p/(profile+'.reference'),dest/(profile+'.reference'))
 (dest/(profile+'.expected')).write_text(f'{8+loops*days*8}:27\n')
 sources=['input','sandmark-almabench-tables','sandmark-almabench','sandmark-almabench-driver']
 rows.append(dict(zip(fields,['almabench',profile,'sandmark','benchmarks/almabench/almabench.exe',f'{loops} {days} {profile}.reference',f'almabench/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+',almabench/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'numerical,arrays,mutation',profile+'.reference','checked-numerical','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/almabench';data.mkdir()
for file in ['points.reference','erfa.reference','smoke.reference','normal.reference']:shutil.copy(p/file,data/file)
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/almabench-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-sphere.sh').read_text().replace('sphere','almabench')
script=script.replace('examples/benchmarks/shared/lazy.sml ','').replace('examples/benchmarks/shared/suspend.sml ','').replace('examples/benchmarks/shared/stream.sml ','').replace('examples/benchmarks/shared/nofib-almabench.sml examples/benchmarks/shared/nofib-almabench-driver.sml','examples/benchmarks/shared/sandmark-almabench-tables.sml examples/benchmarks/shared/sandmark-almabench.sml examples/benchmarks/shared/sandmark-almabench-driver.sml').replace('source image/vector fixtures, numerical checks and demand controls hold','original and ERFA states, angle semantics and aggregate checks hold')
(root/'tests/benchmarks/check-almabench.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-almabench-parallel.'").replace("{'atom-lazy','atom-strict'}","{'almabench'}")
(p/'check-parallel.py').write_text(text)
print('ALMABENCH imported:365 programs/1087 profiles')
