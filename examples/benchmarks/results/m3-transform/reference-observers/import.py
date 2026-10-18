from pathlib import Path
import csv,shutil
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
for part,filename in [('inputs','inputs.sml'),('kernel','kernel-final.sml'),('check','check.sml')]:shutil.copy(p/filename,s/'shared'/('transform-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['transform-lazy','transform-strict'];assert not any(r['benchmark']in names for r in rows)
for name,policy in zip(names,['BenchNeed','BenchStrict']):
 d=s/name;d.mkdir();up=d/'upstream';up.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchTransformFn('+policy+')\n structure Check=BenchTransformCheckFn(Kernel)\n val run=Check.run\nend\n')
 for filename in ['Main.hs','Makefile','transform.faststdout','transform.stdout','transform.slowstdout']:shutil.copy(p/'source'/filename,up/filename)
 shutil.copy(p/'Fast2haskell.hs',up/'Fast2haskell.hs')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 for profile,count,expected,seconds,memory in [('smoke',8,28275,30,1048576),('normal',3000,10603125,600,4194304),('large',15000,53015625,3600,8388608)]:
  (d/(profile+'.expected')).write_text(str(expected)+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml','shared/transform-inputs.sml','shared/transform-kernel.sml','shared/transform-check.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/transform',str(count),name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'compiler-application,parsing,rewriting,dataflow,streams,higher-order,sharing,allocation-lifetimes,hartel','-','exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/transform-tests.sml')
data=root/'tests/benchmarks/data/transform';shutil.copytree(p/'data',data);(data/'FILES').write_text((p/'data-list').read_text())
(data/'.gitattributes').write_text('*.input -text -whitespace\n*.reference -text -whitespace\n')
script=(root/'tests/benchmarks/check-parstof.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+['examples/benchmarks/shared/transform-'+part+'.sml'for part in ['inputs','kernel','check']]+['tests/benchmarks/transform-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('parstof','transform').replace('complete token/AST states, source checksums, parser demand and sharing controls hold','complete transformation states/reports, source sums, character demand and sharing controls hold')
(root/'tests/benchmarks/check-transform.sh').write_text(script)
parallel=(p.parent/'hartel-parstof-originals/check-parallel.py').read_text().replace("{'parstof-strict', 'parstof-lazy'}",repr(set(names))).replace("{'parstof-lazy', 'parstof-strict'}",repr(set(names))).replace('final-parstof-parallel.','final-transform-parallel.')
(p/'check-parallel.py').write_text(parallel)
print('imported Transform2policies')
