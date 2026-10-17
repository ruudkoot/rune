from pathlib import Path
import csv,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/kb-sandmark-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/kb'
shared=['terms','rewrite-raise','rewrite-option','order','completion','data','driver']
for part in shared:shutil.copy(p/(part+'.sml'),suite/'shared'/('sandmark-kb-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in{'kb','kb_no_exc'}for r in rows)
for name,policy,rewriter in [('kb','raise','Raise'),('kb_no_exc','option','Option')]:
 dest=suite/name;dest.mkdir()
 if name=='kb':shutil.copytree(up,dest/'upstream');shutil.copy(p/'QPL-1.0.txt',dest/'QPL-1.0.txt')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 shutil.copy(p/(name+'.rules'),dest/'completed.rules')
 (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchSandmarkKBCompletionFn (BenchSandmarkKB{rewriter})
  structure Driver = BenchSandmarkKBDriverFn (Kernel)
  val run = Driver.run
end
''')
 for profile,repeats in [('smoke',1),('normal',100),('large',1000)]:
  (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*24}\n')
  parts=['terms','rewrite-'+policy,'order','completion','data','driver']
  sources='shared/input.sml,'+','.join('shared/sandmark-kb-'+part+'.sml'for part in parts)+f',{name}/benchmark.sml,shared/main.sml'
  rows.append(dict(zip(fields,[name,profile,'sandmark',f'benchmarks/kb/{name}.exe',f'{repeats} completed.rules',f'{name}/{profile}.expected',sources,str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'symbolic-search,higher-order,exceptions', 'completed.rules','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/sandmark-kb';data.mkdir();shutil.copy(p/'kb.rules',data/'kb.rules')
text=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""').replace('"'+str(p)+'/kb.rules"','"kb.rules"')
(root/'tests/benchmarks/sandmark-kb-tests.sml').write_text(text)
script=(root/'tests/benchmarks/check-fft2.sh').read_text()
a=script.index('for source in ');b=script.index('; do',a)
sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml']+['examples/benchmarks/shared/sandmark-kb-'+part+'.sml'for part in shared]+['tests/benchmarks/sandmark-kb-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(sources)+script[b:]
script=script.replace('fft2','sandmark-kb').replace('source transforms, numerical bounds, quoted output and demand checks hold','source completed rules, critical pairs, matching and unification controls hold')
(root/'tests/benchmarks/check-sandmark-kb.sh').write_text(script)
text=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-sandmark-kb-parallel.'").replace("{'atom-lazy','atom-strict'}","{'kb','kb_no_exc'}")
(p/'check-parallel.py').write_text(text)
print('KB imported:367programs/1093profiles')
