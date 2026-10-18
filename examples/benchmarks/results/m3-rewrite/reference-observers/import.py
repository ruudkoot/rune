from pathlib import Path
import csv,shutil
r=Path.cwd();s=r/'examples/benchmarks';p=r/'tests/out/benchmarks/rewrite-originals';up=r/'tests/out/benchmarks/pinned/nofib/spectral/rewrite'
parts=['expr','parser','kernel','driver']
for part in parts:shutil.copy(p/(part+'.sml'),s/'shared'/('nofib-rewrite-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:q=csv.DictReader(f,delimiter='\t');fields=q.fieldnames;rows=list(q)
assert not any(x['benchmark']in['rewrite-lazy','rewrite-strict']for x in rows)
for mode in ['lazy','strict']:
 name='rewrite-'+mode;d=s/name;d.mkdir()
 if mode=='lazy':shutil.copytree(up,d/'upstream')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Program=BenchRewriteFn(val eagerChildren='+str(mode=='strict').lower()+')\n structure Driver=BenchRewriteDriverFn(Program)\n val run=Driver.run\nend\n')
 for profile,n in [('smoke',1),('normal',250000),('large',1200000)]:
  (d/(profile+'.expected')).write_text('True\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/stream.sml']+['shared/nofib-rewrite-'+x+'.sml'for x in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/rewrite',str(n),name+'/'+profile+'.expected',','.join(sources),str(dict(smoke=30,normal=600,large=3600)[profile]),str(dict(smoke=1048576,normal=4194304,large=8388608)[profile]),'symbolic-search,higher-order,lists-streams,'+mode,'-','exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=r/'tests/benchmarks/data/rewrite';data.mkdir();shutil.copy(p/'theory.reference',data/'theory.reference')
(r/'tests/benchmarks/rewrite-tests.sml').write_text((p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""'))
script=(r/'tests/benchmarks/check-hartel-typecheck.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/nofib-rewrite-'+x+'.sml'for x in parts]+['tests/benchmarks/rewrite-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('hartel-typecheck','rewrite').replace('original inferred types, functional substitutions, fold ordering and checksum-collision rejection hold','original completion theory, independent free-group forms, substitutions and demand checks hold')
(r/'tests/benchmarks/check-rewrite.sh').write_text(script)
script=(r/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-rewrite-parallel.'").replace("{'atom-lazy','atom-strict'}","{'rewrite-lazy','rewrite-strict'}")
(p/'check-parallel.py').write_text(script)
