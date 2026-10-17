from pathlib import Path
import csv,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/bspt-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/real/bspt'
parts=['rational','geometry','tree','ui','program','driver']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('nofib-bspt-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in{'bspt-lazy','bspt-strict'}for r in rows)
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='bspt-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(up,dest/'upstream')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\nbatch.render -text -whitespace\n')
 shutil.copy(up/'bspt.stdin',dest/'commands.txt');shutil.copy(p/'batch.render',dest/'batch.render')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Program = BenchBSPTProgramFn (Bench{policy})
  structure Driver = BenchBSPTDriverFn (Program)
  val run = Driver.run
end
''')
 for profile,repeats in [('smoke',1),('normal',25000),('large',125000)]:
  (dest/(profile+'.expected')).write_text(f'{repeats} {repeats*9761} 2674C83CE2E76A07\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/stream.sml']+['shared/nofib-bspt-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','real/bspt',f'{repeats} commands.txt batch.render',f'{name}/{profile}.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'integer-arithmetic,graphs,higher-order,lists-streams,'+mode,'commands.txt,batch.render','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/bspt';data.mkdir()
shutil.copy(p/'rational.reference',data/'rational.reference');shutil.copy(p/'batch.render',data/'batch.render');shutil.copy(up/'bspt.stdin',data/'commands.txt')
shutil.copytree(p/'cases',data/'cases')
(data/'.gitattributes').write_text('batch.render -text -whitespace\ncases/** -text -whitespace\n')
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""').replace('"'+str(p)+'/batch.render"','"batch.render"').replace('base^"source/bspt.stdin"','base^"commands.txt"')
assert 'source/bspt.stdin'not in text
(root/'tests/benchmarks/bspt-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-linear.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/nofib-bspt-'+part+'.sml'for part in parts]+['tests/benchmarks/bspt-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(sources)+script[b:]
script=script.replace('linear','bspt').replace('original Float block/preconditioner metrics, higher-order demand and text consumers hold','original geometric commands, signed rational arithmetic, tree demand and batch sharing hold')
script=script.replace('for file in tests/benchmarks/data/bspt/*; do basename "$file"; done > "$out/data.txt"',"""python3 - <<'DATA' > "$out/data.txt"
from pathlib import Path
base=Path("tests/benchmarks/data/bspt")
for file in sorted(base.rglob("*")):
    if file.is_file() and file.name != ".gitattributes":
        print(file.relative_to(base))
DATA""")
(root/'tests/benchmarks/check-bspt.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-bspt-parallel.'").replace("{'atom-lazy','atom-strict'}","{'bspt-lazy','bspt-strict'}")
(p/'check-parallel.py').write_text(text)
print('BSPT imported:376 programs/1120 profiles')
