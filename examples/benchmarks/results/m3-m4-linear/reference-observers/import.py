from pathlib import Path
import csv,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/linear-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib'
for part in ['float','dense','kernel','driver']:shutil.copy(p/(part+'.sml'),suite/'shared'/('nofib-linear-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=[]
for kind,limit,profiles in [('real',10,[('smoke',1,2),('normal',200,4),('large',200,7)]),('gc',50,[('smoke',1,2),('normal',1,14),('large',1,16)])]:
 for mode,policy in [('lazy','Need'),('strict','Strict')]:
  name=('linear'if kind=='real'else'linear-nofib-gc')+'-'+mode;names.append(name);dest=suite/name;dest.mkdir()
  if kind=='real'and mode=='lazy':
   shutil.copytree(up/'real/linear',dest/'upstream-real')
   shutil.copytree(up/'gc/linear',dest/'upstream-gc')
  (dest/'.gitattributes').write_text('upstream-real/** -text -whitespace\nupstream-gc/** -text -whitespace\n')
  (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchLinearFn (Bench{policy})
  structure Driver = BenchLinearDriverFn
    (struct type number = Kernel.number val stats = Kernel.stats val value = Kernel.B.value end)
  val run = Driver.run "{kind}"
end
''')
  for profile,repeats,n in profiles:
   metrics=p/(kind+'-'+profile+'.metrics');shutil.copy(metrics,dest/(profile+'.metrics'))
   count=len(metrics.read_text().splitlines());characters=85+63*count
   (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*count}:{repeats*characters}\n')
   sources=['input','lazy','suspend','stream','nofib-linear-float','nofib-linear-dense','nofib-linear-kernel','nofib-linear-driver']
   rows.append(dict(zip(fields,[name,profile,'nofib',kind+'/linear',f'{repeats} {n} {limit} {profile}.metrics',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'numerical,higher-order,lists-streams,'+mode,profile+'.metrics','checked-numerical','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/linear';data.mkdir()
for name in ['math.reference','real-smoke.metrics','gc-smoke.metrics','small3.metrics']:shutil.copy(p/name,data/name)
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/linear-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-fft2.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/nofib-linear-'+part+'.sml'for part in ['float','dense','kernel','driver']]+['tests/benchmarks/linear-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(sources)+script[b:]
script=script.replace('fft2','linear').replace('source transforms, numerical bounds, quoted output and demand checks hold','original Float block/preconditioner metrics, higher-order demand and text consumers hold')
(root/'tests/benchmarks/check-linear.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-linear-parallel.'").replace("{'atom-lazy','atom-strict'}",repr(set(names)))
(p/'check-parallel.py').write_text(text)
print('Linear imported:374 programs/1114 profiles')
