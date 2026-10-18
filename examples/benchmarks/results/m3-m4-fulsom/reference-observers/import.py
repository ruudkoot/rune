from pathlib import Path
import csv,shutil,hashlib,json
root=Path.cwd();s=root/'examples/benchmarks';p=Path(__file__).resolve().parent
names=['fulsom-lazy','fulsom-strict','fulsom-nofib-lazy','fulsom-nofib-strict']
parts=['interval','kernel','check']
for part in parts:shutil.copy(p/(part+'.sml'),s/'shared'/('fulsom-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
for name in names:
 family='real'if'nofib'in name else'gc';policy='BenchNeed'if name.endswith('lazy')else'BenchStrict';hashed=family=='real'
 d=s/name;d.mkdir()
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Kernel=BenchFulsomFn('+policy+')\n structure Check=BenchFulsomCheckFn(Kernel)\n val run=Check.'+('runHashed'if hashed else'runRaw')+'\nend\n')
 u=d/'upstream';u.mkdir()
 originals=p.parent/'pinned/nofib'/family/'fulsom'
 # Only reviewed text sources and notices. Binary raster fixtures are encoded
 # below, with source identity, rather than imported as executable payloads.
 for file in originals.iterdir():
  if file.is_file()and(file.suffix in ['.hs','.lhs']or file.name in ['Makefile','MAIL','README.original','README.nofib']):shutil.copy(file,u/file.name)
 if hashed:
  for file in originals.glob('fulsom.*stdout'):shutil.copy(file,u/file.name)
  assert(u/'NofibUtils.hs').exists()
 (u/'raster').mkdir();shutil.copy(originals/'raster/raster.c',u/'raster/raster.c')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 profiles=[('smoke',1,4),('normal',1000,5),('large',1000,6)]if hashed else[('smoke',1,4),('normal',1,7),('large',1,9)]
 for profile,reps,depth in profiles:
  seconds,memory={'smoke':(30,1048576),'normal':(600,4194304),'large':(3600,8388608)}[profile]
  data=bytes.fromhex((p/('depth-'+str(depth)+'.hex')).read_text())
  (d/(profile+'.hex')).write_text(data.hex()+'\n')
  h=0
  for b in data:h=(31*h+b)%(1<<64)
  if h>=1<<63:h-=1<<64
  args=(str(reps)+' 'if hashed else'')+str(depth)+' '+profile+'.hex'+(' '+str(h)if hashed else'')
  wanted=str(reps)+':'+str(reps*len(data))if hashed else str(len(data))
  (d/(profile+'.expected')).write_text(wanted+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/stream.sml','shared/hartel-ida-finite.sml']+['shared/fulsom-'+x+'.sml'for x in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib',family+'/fulsom/Main.hs',args,name+'/'+profile+'.expected',','.join(sources),str(seconds),str(memory),'applications,csg,interval-arithmetic,octrees,quadtrees,streams,sharing,allocation-lifetimes',profile+'.hex','exact','implemented'])))
 # Original source-profile raster identities; exact ASCII representation is a
 # reversible transport, never a changed numerical expected result.
 with(u/'raster-identities.tsv').open('w')as f:
  f.write('profile\tdepth\tbytes\tsha256\tencoding\n')
  for label,depth in [('source-fast',7),('source-normal',9)]:
   raw=bytes.fromhex((p/('depth-'+str(depth)+'.hex')).read_text())
   f.write(label+'\t'+str(depth)+'\t'+str(len(raw))+'\t'+hashlib.sha256(raw).hexdigest()+'\tlowercase hexadecimal with terminal LF\n')
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
shutil.copy(p/'tests-final.sml',root/'tests/benchmarks/fulsom-tests.sml')
data=root/'tests/benchmarks/data/fulsom';data.mkdir()
for depth in range(6):shutil.copy(p/('depth-'+str(depth)+'.hex'),data)
script=(root/'tests/benchmarks/check-wave4main.sh').read_text()
a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml','examples/benchmarks/shared/hartel-ida-finite.sml']+['examples/benchmarks/shared/fulsom-'+x+'.sml'for x in parts]+['tests/benchmarks/fulsom-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
a=script.index("printf 'steps-8.reference");b=script.index('\nstatus=0',a)
script=script[:a]+"printf '%s\\n' "+' '.join('depth-'+str(i)+'.hex'for i in range(6))+' > "$out/data.txt"'+script[b:]
script=script.replace('wave4main','fulsom').replace('complete original wave states, independent stencils, bounds and demand controls hold','original interval, complete raster/hash and demand checks hold')
(root/'tests/benchmarks/check-fulsom.sh').write_text(script)
checker=(p.parent/'hartel-wave4main-originals/check-parallel.py').read_text().replace("{'wave4main-lazy','wave4main-strict'}",repr(set(names))).replace('final-wave4main-parallel.','final-fulsom-parallel.')
(p/'check-parallel.py').write_text(checker)
print('Imported four Fulsom consumer/data policies;12profiles')
