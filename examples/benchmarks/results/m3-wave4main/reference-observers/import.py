from pathlib import Path
import csv,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/hartel-wave4main-originals'
parts=['array','kernel','check']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('hartel-wave4main-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['wave4main-lazy','wave4main-strict'];assert not any(r['benchmark']in names for r in rows)
for name,policy in zip(names,['BenchNeed','BenchStrict']):
 d=suite/name;d.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchWave4Fn('+policy+')\n structure Check=BenchWaveCheckFn(Kernel)\n val run=Check.run\nend\n')
 (d/'upstream').mkdir()
 for file in ['Main.hs','Makefile','wave4main.faststdout','wave4main.stdout','wave4main.slowstdout']:shutil.copy(p/'source'/file,d/'upstream'/file)
 shutil.copy(p/'Fast2haskell.hs',d/'upstream/Fast2haskell.hs')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 for profile,repetitions,steps,seconds,memory in [('smoke',1,8,30,1048576),('normal',500,80,600,4194304),('large',500,400,3600,8388608)]:
  reference=profile+'.reference';shutil.copy(p/('steps-'+str(steps)+'.reference'),d/reference)
  (d/(profile+'.expected')).write_text(str(repetitions)+':208\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml']+['shared/hartel-wave4main-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/wave4main',str(repetitions)+' '+str(steps)+' '+reference,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'numerical,arrays,indexed-data,sharing,allocation-lifetimes,hartel',reference,'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests-final.sml',root/'tests/benchmarks/wave4main-tests.sml')
data=root/'tests/benchmarks/data/wave4main';data.mkdir();shutil.copy(p/'steps-8.reference',data/'steps-8.reference')
script=(root/'tests/benchmarks/check-lexifi-g2pp.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml']+['examples/benchmarks/shared/hartel-wave4main-'+part+'.sml'for part in parts]+['tests/benchmarks/wave4main-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
a=script.index('for file in ');b=script.index('\nstatus=0',a)
script=script[:a]+'printf \'steps-8.reference\\n\' > "$out/data.txt"'+script[b:]
script=script.replace('lexifi-g2pp-checks','wave4main-checks').replace('bench-lexifi-g2pp','bench-wave4main').replace('data/lexifi-g2pp','data/wave4main')
script=script.replace('source calibration prices, optimizer traces and numerical controls hold','complete original wave states, independent stencils, bounds and demand controls hold')
(root/'tests/benchmarks/check-wave4main.sh').write_text(script)
script=(p.parent/'hartel-sched-originals/check-parallel.py').read_text().replace("{'sched-lazy','sched-strict'}","{'wave4main-lazy','wave4main-strict'}").replace('final-hartel-sched-parallel.','final-wave4main-parallel.')
assert "wave4main-lazy"in script
(p/'check-parallel.py').write_text(script)
print('Imported two wave variants with six full-numeric profiles')
