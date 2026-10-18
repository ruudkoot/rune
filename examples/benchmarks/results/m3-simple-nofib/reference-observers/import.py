from pathlib import Path
import csv,shutil
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
for part in ['arrays','kernel','check']:shutil.copy(p/(part+'.sml'),s/'shared'/('simple-nofib-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['simple-nofib-lazy','simple-nofib-strict','simple-nofib-report-lazy','simple-nofib-report-strict']
assert not any(r['benchmark']in names for r in rows)
for name in names:
 report='-report-'in name;strict=name.endswith('-strict')
 d=s/name;d.mkdir();up=d/'upstream';up.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Check=BenchSimpleCheckFn(val strict='+str(strict).lower()+' val report='+str(report).lower()+' val gridMax=100)\n val run=Check.run\nend\n')
 for file in ['Main.hs','Makefile','MAIL','simple.c','simple.f']:shutil.copy(p/'source'/file,up/file)
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 for profile,count,seconds,memory in [('smoke',1,30,1048576),('normal',20,600,4194304),('large',100,3600,8388608)]:
  source=('state-'if report else'totals-')+'100-'+str(count)+'.reference'
  reference=profile+'.reference';shutil.copy(p/'data'/source,d/reference)
  expected=str(count)+':'+('110004'if report else'13')+'\n'
  (d/(profile+'.expected')).write_text(expected)
  sources=['shared/input.sml','shared/lazy.sml','shared/simple-nofib-arrays.sml','shared/simple-nofib-kernel.sml','shared/simple-nofib-check.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/simple',str(count)+' '+reference,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'numerical,binary64,immutable-arrays,recursive-arrays,hydrodynamics,sharing,allocation-lifetimes'+(',formatting,io'if report else',reductions'),reference,'exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/simple-nofib-tests.sml')
data=root/'tests/benchmarks/data/simple-nofib';shutil.copytree(p/'data',data);(data/'FILES').write_text((p/'data-list').read_text())
script=(root/'tests/benchmarks/check-parstof.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml']+['examples/benchmarks/shared/simple-nofib-'+part+'.sml'for part in ['arrays','kernel','check']]+['tests/benchmarks/simple-nofib-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('parstof','simple-nofib').replace('complete token/AST states, source checksums, parser demand and sharing controls hold','complete numerical states, recursive array sharing, source consumers and tolerance controls hold')
(root/'tests/benchmarks/check-simple-nofib.sh').write_text(script)
parallel=(p.parent/'hartel-transform-originals/check-parallel.py').read_text().replace("{'transform-lazy', 'transform-strict'}",repr(set(names))).replace("{'transform-strict', 'transform-lazy'}",repr(set(names))).replace('final-transform-parallel.','final-simple-nofib-parallel.')
assert 'transform-lazy'not in parallel
(p/'check-parallel.py').write_text(parallel)
print('imported four SIMPLE consumers/policies; 489 programs/1421 profiles')
