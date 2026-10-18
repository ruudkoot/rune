from pathlib import Path
import shutil,csv
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
for part in ['kernel','print','check','serialize']:
 t=(p/(part+'.sml')).read_text()
 # Synthetic AST constructors belong to the semantic target, not the benchmark kernel.
 if part=='kernel':
  a=t.index('fun cases()=')
  cases=t[a:t.rindex('\nend')]
  t=t[:a]+'end\n'
  (p/'test-cases-body.sml').write_text(cases)
 (s/'shared'/('lift-'+part+'.sml')).write_text(t)
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['lift-lazy','lift-strict'];assert not any(r['benchmark']in names for r in rows)
h=(p/'hash.reference').read_text().strip()
for name,strict in zip(names,['false','true']):
 d=s/name;d.mkdir();up=d/'upstream';up.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchLiftFn(val strict='+strict+')\n structure Check=BenchLiftCheckFn(Kernel)\n val run=Check.run\nend\n')
 for f in (p/'source').iterdir():
  if f.is_file()and f.suffix in ['.hs','.lhs']or f.is_file()and(f.name=='Makefile'or f.name.endswith('stdout')):shutil.copy(f,up/f.name)
 shutil.copy(p/'report.reference',d/'report.reference')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\nreport.reference -text -whitespace\n')
 for profile,reps,seconds,memory in [('smoke',1,30,1048576),('normal',4000,600,4194304),('large',20000,3600,8388608)]:
  (d/(profile+'.expected')).write_text(str(reps)+':'+str(reps*1948)+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/lift-kernel.sml','shared/lift-print.sml','shared/lift-check.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','real/lift',str(reps)+' report.reference '+h,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'compiler-application,lambda-lifting,full-laziness,higher-order,sharing,symbolic','report.reference','exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
tests=(p/'mlkit-unrolled-tests.sml').read_text()
cases=(p/'test-cases-body.sml').read_text().replace('fun cases()=','fun cases()=',1)
tests=tests.replace(' structure NS=', ' structure NS=',1)
for label in ['N','E']:
 tests=tests.replace(' structure '+label+'S=',' structure '+label+'Cases=struct\n open '+label+'\n '+cases+'\nend\n structure '+label+'S=',1)
 tests=tests.replace(label+'.cases()',label+'Cases.cases()')
(root/'tests/benchmarks/lift-tests.sml').write_text(tests)
data=root/'tests/benchmarks/data/lift';shutil.copytree(p/'data',data);(data/'FILES').write_text((p/'data-list').read_text())
(data/'.gitattributes').write_text('*.reference -text -whitespace\n')
script=(root/'tests/benchmarks/check-solid.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml']+['examples/benchmarks/shared/lift-'+part+'.sml'for part in ['kernel','print','check','serialize']]+['tests/benchmarks/lift-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('solid','lift').replace('corrected CSG tables, complete adaptive trees, geometric areas and demand controls hold','complete lambda-lifted ASTs, reports, renaming knots and forcing controls hold')
(root/'tests/benchmarks/check-lift.sh').write_text(script)
parallel=(p.parent/'hartel-solid-originals/check-parallel.py').read_text().replace("{'solid-strict', 'solid-lazy'}",repr(set(names))).replace('final-solid-parallel.','final-lift-parallel.')
(p/'check-parallel.py').write_text(parallel)
print('Imported two lift policies')
