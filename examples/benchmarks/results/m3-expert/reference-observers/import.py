from pathlib import Path
import csv,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/expert-originals'
parts=['table','phrase','program','driver']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('nofib-expert-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in{'expert-lazy','expert-strict'}for r in rows)
for mode,flag in [('lazy','false'),('strict','true')]:
 name='expert-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':shutil.copytree(p/'source',dest/'upstream',ignore=shutil.ignore_patterns('*.o','*.hi','original','build.log'))
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\ndialog.txt -text -whitespace\n')
 shutil.copy(p/'source/runtime_files/animals',dest/'animals.txt');shutil.copy(p/'source/expert.stdin',dest/'answers.txt');shutil.copy(p/'cases/source.output',dest/'dialog.txt')
 (dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "'+name+'"\n  structure Program = BenchExpertFn (struct val eagerTerms = '+flag+' end)\n  structure Driver = BenchExpertDriverFn (Program)\n  val run = Driver.run\nend\n')
 for profile,count in [('smoke',1),('normal',10000),('large',50000)]:
  (dest/(profile+'.expected')).write_text(str(count)+' '+str(count*526)+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/stream.sml']+['shared/nofib-expert-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/expert',str(count)+' animals.txt answers.txt dialog.txt',name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'symbolic,search,graphs,lists-streams,'+mode,'animals.txt,answers.txt,dialog.txt','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/expert';data.mkdir();shutil.copytree(p/'cases',data/'cases');shutil.copy(p/'source/runtime_files/animals',data/'animals.txt');shutil.copy(p/'source/expert.stdin',data/'answers.txt')
(data/'.gitattributes').write_text('cases/** -text -whitespace\n')
s=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""').replace('source/runtime_files/animals','animals.txt').replace('source/expert.stdin','answers.txt');(root/'tests/benchmarks/expert-tests.sml').write_text(s)
script=(root/'tests/benchmarks/check-bspt.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/nofib-expert-'+part+'.sml'for part in parts]+['tests/benchmarks/expert-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('bspt','expert').replace('original geometric commands, signed rational arithmetic, tree demand and batch sharing hold','original dialogs, lazy feedback tables, unification and answer demand hold');(root/'tests/benchmarks/check-expert.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-expert-parallel.'").replace("{'atom-lazy','atom-strict'}","{'expert-lazy','expert-strict'}");(p/'check-parallel.py').write_text(s)
