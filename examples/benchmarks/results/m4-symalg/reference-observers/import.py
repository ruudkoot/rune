from pathlib import Path
import csv,shutil,hashlib,math,json
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
parts=['real','number','kernel','check'];names=['symalg-lazy','symalg-strict']
for part in parts:shutil.copy(p/(part+'.sml'),s/'shared'/('symalg-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
for name,policy in zip(names,['BenchNeed','BenchStrict']):
 d=s/name;d.mkdir();u=d/'upstream';u.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchSymalgFn('+policy+')\n structure Check=BenchSymalgCheckFn(Kernel)\n val run=Check.run\nend\n')
 for f in (p.parent/'pinned/nofib/real/symalg').iterdir():
  if f.is_file():shutil.copy(f,u/f.name)
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 for profile,prefix,seconds,memory in [('smoke','smoke',30,1048576),('normal','selected-normal300',600,4194304),('large','selected-large3000',3600,8388608)]:
  for suffix in ['stdin','numbers.reference','stdout']:shutil.copy(p/(prefix+'.'+suffix),d/(profile+'.'+suffix))
  output=(p/(prefix+'.stdout')).read_bytes()
  (d/(profile+'.expected')).write_text('11:'+str(len(output))+'\n')
  args=' '.join(profile+'.'+suffix for suffix in ['stdin','numbers.reference','stdout'])
  sources=['shared/lazy.sml','shared/suspend.sml']+['shared/symalg-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','real/symalg',args,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'applications,parsing,exact-reals,integer-arithmetic,sharing,higher-order',','.join(profile+'.'+suffix for suffix in ['stdin','numbers.reference','stdout']),'exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests-final.sml',root/'tests/benchmarks/symalg-tests.sml')
data=root/'tests/benchmarks/data/symalg';shutil.copytree(p/'data',data)
shutil.copy(p/'check-adapter.sh',root/'tests/benchmarks/check-symalg.sh')
checker=(p.parent/'hartel-wave4main-originals/check-parallel.py').read_text().replace("{'wave4main-lazy','wave4main-strict'}","{'symalg-lazy','symalg-strict'}").replace('final-wave4main-parallel.','final-symalg-parallel.')
(p/'check-parallel.py').write_text(checker)
# Independently validate selected full-number fixtures using integer square roots.
records=[]
for prefix,precision in [('smoke',20),('selected-normal300',300),('selected-large3000',3000)]:
 vals=(p/(prefix+'.numbers.reference')).read_text().splitlines();assert len(vals)==11
 gaps=[]
 for n,value in zip(range(2,11),vals[2:],strict=True):
  whole,frac=value.split('.');assert len(frac)==precision
  gap=int(whole+frac)-math.isqrt(n*10**(2*precision));assert abs(gap)<=1;gaps.append(gap)
 records.append(dict(profile=prefix,precision=precision,values=9,min_gap=min(gaps),max_gap=max(gaps)))
(p/'selected-independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
print('Imported two Symalg policies; full selected values independently agree')
