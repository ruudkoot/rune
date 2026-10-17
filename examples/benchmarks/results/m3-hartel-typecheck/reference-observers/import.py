from pathlib import Path
import csv,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/hartel-typecheck-originals';up=root/'tests/out/benchmarks/pinned/nofib/spectral/hartel/typecheck'
parts=['types','infer','program','driver']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('hartel-typecheck-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in{'typecheck-lazy','typecheck-strict'}for r in rows)
for mode,flag in [('lazy','false'),('strict','true')]:
 name='typecheck-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':
  shutil.copytree(up,dest/'upstream/typecheck');shutil.copy(up.parent/'Fast2haskell.hs',dest/'upstream/Fast2haskell.hs')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\ninferred-types.txt -text -whitespace\n')
 shutil.copy(p/'rows.reference',dest/'inferred-types.txt')
 (dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "'+name+'"\n  structure Program = BenchHartelTypecheckProgramFn (struct val eagerChildren = '+flag+' end)\n  structure Driver = BenchHartelTypecheckDriverFn (Program)\n  val run = Driver.run\nend\n')
 for profile,count in [('smoke',1),('normal',5000),('large',25000)]:
  shutil.copy(p/(profile+'.stdout'),dest/(profile+'.expected'))
  sources=['shared/input.sml','shared/lazy.sml','shared/stream.sml']+['shared/hartel-typecheck-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/typecheck',str(count)+' inferred-types.txt',name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'symbolic,higher-order,compiler-application,lists-streams,'+mode,'inferred-types.txt','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/hartel-typecheck';data.mkdir()
for file in ['rows.reference','wrong-rows.reference','cases.reference','helpers.reference','smoke.stdout']:shutil.copy(p/file,data/file)
(data/'.gitattributes').write_text('*.reference -text -whitespace\n')
(root/'tests/benchmarks/hartel-typecheck-tests.sml').write_text((p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""'))
script=(root/'tests/benchmarks/check-linear.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/hartel-typecheck-'+part+'.sml'for part in parts]+['tests/benchmarks/hartel-typecheck-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('linear','hartel-typecheck').replace('original Float block/preconditioner metrics, higher-order demand and text consumers hold','original inferred types, functional substitutions, fold ordering and checksum-collision rejection hold');(root/'tests/benchmarks/check-hartel-typecheck.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-hartel-typecheck-parallel.'").replace("{'atom-lazy','atom-strict'}","{'typecheck-lazy','typecheck-strict'}");(p/'check-parallel.py').write_text(s)
