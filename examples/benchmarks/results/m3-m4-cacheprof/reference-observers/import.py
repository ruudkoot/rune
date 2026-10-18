from pathlib import Path
import csv,shutil,hashlib
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
names=['cacheprof-lazy','cacheprof-strict','cacheprof-nofib-lazy','cacheprof-nofib-strict']
parts=['architecture','kernel','check']
for part in parts:shutil.copy(p/(part+'.sml'),s/'shared'/('cacheprof-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
hooks=(p/'gc/source/cacheprof_hooks2_x86.s').read_bytes()
for name in names:
 real='nofib'in name;family='real'if real else'gc';policy='BenchNeed'if name.endswith('lazy')else'BenchStrict'
 d=s/name;d.mkdir();u=d/'upstream';source=p.parent/'pinned/nofib'/family/'cacheprof'
 shutil.copytree(source,u)
 shutil.copy('/usr/share/common-licenses/GPL-2',u/'COPYING')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n*.s -text -whitespace\n*.reference -text -whitespace\n')
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchCacheprofFn('+policy+')\n structure Check=BenchCacheprofCheckFn(Kernel)\n val run=Check.'+('runForced'if real else'runRaw')+'\nend\n')
 (d/'hooks.s').write_bytes(hooks)
 profiles=[('smoke','fast',1),('normal','normal',200 if real else 1),('large','slow'if real else'full',200 if real else 1)]
 for profile,label,repetitions in profiles:
  seconds,memory={'smoke':(30,1048576),'normal':(600,4194304),'large':(3600,8388608)}[profile]
  file={'fast':'cacheprof.faststdin','normal':'cacheprof.stdin','slow':'cacheprof.slowstdin','full':'cacheprof.full'}[label]
  input=(p/'real/source'/file).read_bytes()
  reference=(p/'data/full.annotated').read_bytes()if label=='full'else(p/({'fast':'source-fast','normal':'normal','slow':'source-slow'}[label]+'.annotated')).read_bytes()
  if not real:reference+=hooks
  (d/(profile+'.s')).write_bytes(input);(d/(profile+'.reference')).write_bytes(reference)
  args=(str(repetitions)+' 'if real else'')+profile+'.s '+profile+'.reference hooks.s'
  expected=(str(repetitions)+':'+str(repetitions*len(reference)))if real else str(len(reference))
  (d/(profile+'.expected')).write_text(expected+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/hartel-ida-finite.sml']+['shared/cacheprof-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib',family+'/cacheprof',args,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'applications,parsing,symbolic-processing,code-generation,sharing,allocation-lifetimes',profile+'.s,'+profile+'.reference,hooks.s','exact','implemented'])))
 with(d/'input-origins.tsv').open('w')as f:
  f.write('profile\tsource\tsha256\n')
  for profile,label,_ in profiles:
   file={'fast':'cacheprof.faststdin','normal':'cacheprof.stdin','slow':'cacheprof.slowstdin','full':'cacheprof.full'}[label]
   f.write(profile+'\t'+(family if label=='normal' else'real')+'/cacheprof/'+file+'\t'+hashlib.sha256((p/'real/source'/file).read_bytes()).hexdigest()+'\n')
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests-final.sml',root/'tests/benchmarks/cacheprof-tests.sml')
shutil.copy(p/'tests-large.sml',root/'tests/benchmarks/cacheprof-large-tests.sml')
data=root/'tests/benchmarks/data/cacheprof';shutil.copytree(p/'data',data)
(data/'.gitattributes').write_text('*.s -text -whitespace\n*.annotated -text -whitespace\n*.reference -text -whitespace\ncases/** -text -whitespace\n')
shutil.copy(p/'check-adapter.sh',root/'tests/benchmarks/check-cacheprof.sh')
shutil.copy(p/'check-large-adapter.sh',root/'tests/benchmarks/check-cacheprof-large.sh')
checker=(p.parent/'hartel-wave4main-originals/check-parallel.py').read_text().replace("{'wave4main-lazy','wave4main-strict'}",repr(set(names))).replace('final-wave4main-parallel.','final-cacheprof-parallel.')
(p/'check-parallel.py').write_text(checker)
print('Imported four Cacheprof consumer/data variants and twelve profiles')
