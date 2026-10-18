from pathlib import Path
import csv,shutil
r=Path.cwd();s=r/'examples/benchmarks';p=r/'tests/out/benchmarks/ida-originals';up=r/'tests/out/benchmarks/pinned/nofib/spectral/hartel/ida'
parts=['finite','kernel','driver']
for part in parts:shutil.copy(p/(part+'.sml'),s/'shared'/('hartel-ida-'+part+'.sml'))
with(s/'manifest.tsv').open()as f:q=csv.DictReader(f,delimiter='\t');fields=q.fieldnames;rows=list(q)
assert not any(x['benchmark']in['ida-lazy','ida-strict']for x in rows)
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='ida-'+mode;d=s/name;d.mkdir()
 if mode=='lazy':
  shutil.copytree(up,d/'upstream/ida');shutil.copy(up.parent/'Fast2haskell.hs',d/'upstream/Fast2haskell.hs')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n structure Program=BenchIdaFn(Bench'+policy+')\n structure Driver=BenchIdaDriverFn(Program)\n val run=Driver.run\nend\n')
 for profile,count,width in [('smoke',1,2),('normal',600,3),('large',3000,3)]:
  text=(p/(profile+'.one')).read_text();(d/(profile+'.reference')).write_text(text)
  (d/(profile+'.expected')).write_text(str(count)+' '+str(count*len(text))+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/stream.sml']+['shared/hartel-ida-'+x+'.sml'for x in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/ida',str(count)+' '+str(width)+' '+profile+'.reference',name+'/'+profile+'.expected',','.join(sources),str(dict(smoke=30,normal=600,large=3600)[profile]),str(dict(smoke=1048576,normal=4194304,large=8388608)[profile]),'symbolic-search,higher-order,lists-streams,'+mode,profile+'.reference','exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=r/'tests/benchmarks/data/ida';data.mkdir()
for x in ['smoke.one','normal.one','cases.reference']:shutil.copy(p/x,data/x)
text=(p/'tests.sml').read_text();assert 'val base="'+str(p)+'/"'in text
(r/'tests/benchmarks/ida-tests.sml').write_text(text.replace('val base="'+str(p)+'/"','val base=""'))
script=(r/'tests/benchmarks/check-event.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/hartel-ida-'+x+'.sml'for x in parts]+['tests/benchmarks/ida-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('event','ida').replace('original ida traces, independent clock model, stable ordering and state demand hold','original puzzle paths, independent optimal lengths and branch demand hold')
(r/'tests/benchmarks/check-ida.sh').write_text(script)
script=(r/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-ida-parallel.'").replace("{'atom-lazy','atom-strict'}","{'ida-lazy','ida-strict'}");(p/'check-parallel.py').write_text(script)
