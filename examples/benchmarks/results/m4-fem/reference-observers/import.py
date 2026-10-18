from pathlib import Path
import shutil,csv,json,hashlib
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
parts=['float','arrays','kernel','snapshot','report','check']
for part in parts:shutil.copy(p/(part+'.sml'),s/'shared'/('fem-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
names=['fem-lazy','fem-strict'];assert not any(r['benchmark']in names for r in rows)
references=json.loads((p/'final-reference-results.json').read_text())
for name,strict in [('fem-lazy','false'),('fem-strict','true')]:
 d=s/name;d.mkdir();shutil.copytree(p.parent/'pinned/nofib/real/fem',d/'upstream')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n*.report -text -whitespace\n')
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchFemFn(val strict='+strict+')\n structure Check=BenchFemCheckFn(Kernel)\n val run=Check.run\nend\n')
 for profile,repetitions,file,seconds,memory in [('smoke',1,'data.0',30,1048576),('normal',100,'fem.stdin',600,4194304),('large',500,'fem.stdin',3600,8388608)]:
  info=next(r for r in references if r['input']==file)
  shutil.copy(p/'source'/file,d/(profile+'.model'))
  shutil.copy(p/(file+'.report'),d/(profile+'.report'))
  shutil.copy(p/(file+'.reference'),d/(profile+'.reference'))
  (d/(profile+'.expected')).write_text(':'.join(map(str,[repetitions,repetitions*info['report_bytes'],repetitions*info['result_floats']]))+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml','shared/nofib-linear-float.sml']+['shared/fem-'+part+'.sml'for part in ['float','arrays','kernel','report','check']]+[name+'/benchmark.sml','shared/main.sml']
  args=str(repetitions)+' '+profile+'.model '+profile+'.report '+profile+'.reference'
  rows.append(dict(zip(fields,[name,profile,'nofib','real/fem',args,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'applications,numerical,binary32,cholesky,variable-bandwidth,recursive-arrays,sharing,allocation-lifetimes',profile+'.model,'+profile+'.report,'+profile+'.reference','exact','implemented'])))
 with(d/'input-origins.tsv').open('w')as f:
  f.write('profile\tsource\tsha256\n')
  for profile,file in [('smoke','data.0'),('normal','fem.stdin'),('large','fem.stdin')]:
   f.write(profile+'\treal/fem/'+file+'\t'+hashlib.sha256((p/'source'/file).read_bytes()).hexdigest()+'\n')
  f.write('normal,large\treal/fem/data.3\t'+hashlib.sha256((p/'source/data.3').read_bytes()).hexdigest()+'\n')
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/fem-tests.sml')
data=root/'tests/benchmarks/data/fem';shutil.copytree(p/'data',data)
(data/'FILES').write_text((p/'data-list').read_text());(data/'.gitattributes').write_text('*.report -text -whitespace\n')
script=(root/'tests/benchmarks/check-comp-lab.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml','examples/benchmarks/shared/nofib-linear-float.sml']+['examples/benchmarks/shared/fem-'+part+'.sml'for part in parts]+['tests/benchmarks/fem-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('comp-lab','fem').replace('complete original component states, persistent trees and demand controls hold','complete binary32 FEM states, cyclic arrays, reports and result checks hold')
(root/'tests/benchmarks/check-fem.sh').write_text(script)
checker=(p.parent/'hartel-wave4main-originals/check-parallel.py').read_text().replace("{'wave4main-lazy','wave4main-strict'}",repr(set(names))).replace('final-wave4main-parallel.','final-fem-parallel.')
(p/'check-parallel.py').write_text(checker)
# The historical C comparison is not a maintained nofib invocation.
f=s/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;variants=list(r)
revision=next(r['revision']for r in csv.DictReader((s/'upstreams.tsv').open(),delimiter='\t')if r['source']=='nofib')
path='real/fem/inC/fem.c'
variants.append(dict(zip(fields,['nofib',revision,'real/fem',path,'fem-c-reference','C','historical C comparison implementation','not separately stated in C headers',hashlib.sha256((p/'source/inC/fem.c').read_bytes()).hexdigest(),'exclude','historical C comparison with fixed-size mutable arrays, a date-based run script and FEM_MODEL_DATA output; no maintained nofib Makefile builds or invokes it; preserve the complete inC source/data/timing tree and record its distinct role','no separate individual notice stated in scanned C headers or its README; retain originals without assigning Haskell author credit to these files'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(variants)
print('Imported FEM2policies;6profiles;fulloriginalsource+Ccomparison provenance')
