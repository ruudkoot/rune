from pathlib import Path
import csv,shutil,json,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/regexredux2-originals';up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/benchmarksgame'
name='regexredux2';dest=suite/name;dest.mkdir();(dest/'upstream').mkdir()
for f in ['regexredux2.ml','fasta3.ml','dune','README.md','LICENSE']:shutil.copy(up/f,dest/'upstream'/f)
shutil.copy(up/'LICENSE',dest/'LICENSE');shutil.copy(up.parent.parent/'LICENSE.md',dest/'upstream/SANDMARK-LICENSE.md')
shutil.copy(p/'regex.sml',suite/'shared/sandmark-regexredux-str.sml')
notice='''(* The Computer Language Benchmarks Game, regex-dna by Christophe Troestler;
   Bytes adaptation by Roman Kashitsyn. Revised BSD notice: regexredux2/LICENSE. *)
'''
(suite/'shared/sandmark-regexredux2.sml').write_text(notice+(p/'program.sml').read_text())
(dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "regexredux2"\n  val run = BenchRegexRedux2.run\nend\n')
(dest/'.gitattributes').write_text('upstream/** -text -whitespace\nLICENSE -text -whitespace\n*.fasta -text -whitespace\n')
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']==name for r in rows)
identities=[]
for profile in ['smoke','normal','large']:
 for suffix in ['.fasta','.output']:
  src=p/(profile+suffix);shutil.copy(src,dest/src.name);identities.append(dict(path=src.name,bytes=src.stat().st_size,sha256=hashlib.sha256(src.read_bytes()).hexdigest()))
 (dest/(profile+'.expected')).write_text(str((p/(profile+'.output')).stat().st_size)+'\n')
 sources=['shared/input.sml','shared/sandmark-regexredux-str.sml','shared/sandmark-regexredux2.sml',name+'/benchmark.sml','shared/main.sml']
 rows.append(dict(zip(fields,[name,profile,'sandmark','benchmarks/benchmarksgame/regexredux2.exe',profile+'.fasta '+profile+'.output',name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'strings,search,dna',profile+'.fasta,'+profile+'.output','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
(dest/'DATA-IDENTITIES.json').write_text(json.dumps(identities,indent=2)+'\n')
data=root/'tests/benchmarks/data/regexredux2';data.mkdir();shutil.copytree(p/'cases',data/'cases')
for f in ['smoke.fasta','smoke.output']:shutil.copy(p/f,data/f)
(data/'.gitattributes').write_text('cases/** -text -whitespace\n*.fasta -text -whitespace\n')
(root/'tests/benchmarks/regexredux2-tests.sml').write_text((p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""'))
script=(root/'tests/benchmarks/check-bspt.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/sandmark-regexredux-str.sml','examples/benchmarks/shared/sandmark-regexredux2.sml','tests/benchmarks/regexredux2-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('bspt','regexredux2').replace('original geometric commands, signed rational arithmetic, tree demand and batch sharing hold','original Str matches, overlap, greedy replacement and FASTA results hold');(root/'tests/benchmarks/check-regexredux2.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-regexredux2-parallel.'").replace("{'atom-lazy','atom-strict'}","{'regexredux2'}");(p/'check-parallel.py').write_text(s)
