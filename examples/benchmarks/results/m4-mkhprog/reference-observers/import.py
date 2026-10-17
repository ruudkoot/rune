from pathlib import Path
import csv,json,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/mkhprog-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/real/mkhprog'
for local,public in [('templates.sml','mkhprog-templates.sml'),('kernel.sml','mkhprog.sml'),('driver.sml','mkhprog-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('mkhprog-')for r in rows)
sums=sum(map(int,(p/'default.hashes').read_text().split()))%(2**64)
sources=['input','lazy','suspend','mkhprog-templates','mkhprog','mkhprog-driver']
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='mkhprog-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(up,dest/'upstream',ignore=shutil.ignore_patterns('*.o','*.hi','original','observer','*.rbc'))
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchMkhprogFn (Bench{policy})
  structure Driver = BenchMkhprogDriverFn (Kernel)
  val run = Driver.run
end
''')
 shutil.copy(up/'mkhprog.stdin',dest/'specification.input');shutil.copy(p/'default.hashes',dest/'blocks.hashes')
 for profile,repeats in [('smoke',1),('normal',3800),('large',18000)]:
  (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*62}:{sums*repeats%(2**64):X}\n')
  rows.append(dict(zip(fields,[name,profile,'nofib','real/mkhprog',f'{repeats} specification.input blocks.hashes',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'parsing,higher-order,code-generation,lists-streams,allocation-lifetimes,'+mode,'specification.input,blocks.hashes','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/mkhprog';data.mkdir()
for pattern in ['*.input','*.text','*.hashes','*.channels','*.usage']:
 for file in p.glob(pattern):shutil.copy(file,data/file.name)
(data/'.gitattributes').write_text('*.input -text -whitespace\n*.text -text -whitespace\n')
s=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""')
(root/'tests/benchmarks/mkhprog-tests.sml').write_text(s)
script=(root/'tests/benchmarks/check-pic.sh').read_text().replace('pic','mkhprog')
script=script.replace('examples/benchmarks/shared/nofib-mkhprog.sml examples/benchmarks/shared/nofib-mkhprog-driver.sml',
 'examples/benchmarks/shared/mkhprog-templates.sml examples/benchmarks/shared/mkhprog.sml examples/benchmarks/shared/mkhprog-driver.sml')
script=script.replace('source meshes, particle states, numerical results and demand checks hold','source output blocks, parser choices, hashes, continuations and demand checks hold')
(root/'tests/benchmarks/check-mkhprog.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-mkhprog-parallel.'").replace("{'atom-lazy','atom-strict'}","{'mkhprog-lazy','mkhprog-strict'}")
(p/'check-parallel.py').write_text(s)
