from pathlib import Path
import csv,shutil
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
for part,file in [('lex','lex.sml'),('kernel','kernel-observe.sml'),('check','check.sml')]:shutil.copy(p/file,s/'shared'/('parstof-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['parstof-lazy','parstof-strict'];assert not any(r['benchmark']in names for r in rows)
for name,policy in zip(names,['BenchNeed','BenchStrict']):
 d=s/name;d.mkdir();up=d/'upstream';up.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchParstofFn('+policy+')\n structure Check=BenchParstofCheckFn(Kernel)\n val run=Check.run\nend\n')
 for file in ['Main.hs','Makefile','parstof.faststdout','parstof.stdout','parstof.slowstdout']:shutil.copy(p/'source'/file,up/file)
 shutil.copy(p/'Fast2haskell.hs',up/'Fast2haskell.hs');shutil.copy(p/'program.input',d/'program.input')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\nprogram.input -text -whitespace\n')
 for profile,reps,count,seconds,memory in [('smoke',1,1,30,1048576),('normal',100,8,600,4194304),('large',100,40,3600,8388608)]:
  crc='count-'+str(count)+'.crc';shutil.copy(p/crc,d/crc)
  expected=str(reps)+':'+str(reps*count)+':'+str(reps*len((p/crc).read_text()))+'\n'
  (d/(profile+'.expected')).write_text(expected)
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/parstof-lex.sml','shared/parstof-kernel.sml','shared/parstof-check.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/parstof',str(reps)+' '+str(count)+' program.input '+crc,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'compiler-application,parsing,backtracking,sharing,allocation-lifetimes,hartel','program.input,'+crc,'exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/parstof-tests.sml')
data=root/'tests/benchmarks/data/parstof';shutil.copytree(p/'data',data);(data/'FILES').write_text((p/'data-list').read_text())
(data/'.gitattributes').write_text('*.input -text -whitespace\n')
script=(root/'tests/benchmarks/check-solid.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml']+['examples/benchmarks/shared/parstof-'+part+'.sml'for part in ['lex','kernel','check']]+['tests/benchmarks/parstof-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('solid','parstof').replace('corrected CSG tables, complete adaptive trees, geometric areas and demand controls hold','complete token/AST states, source checksums, parser demand and sharing controls hold')
(root/'tests/benchmarks/check-parstof.sh').write_text(script)
parallel=(p.parent/'hartel-solid-originals/check-parallel.py').read_text().replace("{'solid-strict', 'solid-lazy'}",repr(set(names))).replace('final-solid-parallel.','final-parstof-parallel.')
(p/'check-parallel.py').write_text(parallel)
print('imported Parstof two policies')
