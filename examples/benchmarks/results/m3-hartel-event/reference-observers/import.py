from pathlib import Path
import csv,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/event-originals';up=root/'tests/out/benchmarks/pinned/nofib/spectral/hartel/event'
parts=['finite','kernel','driver']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('hartel-event-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in{'event-lazy','event-strict'}for r in rows)
for mode,policy in [('lazy','Need'),('strict','Strict')]:
 name='event-'+mode;dest=suite/name;dest.mkdir()
 if mode=='lazy':
  shutil.copytree(up,dest/'upstream/event');shutil.copy(up.parent/'Fast2haskell.hs',dest/'upstream/Fast2haskell.hs')
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
 (dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "'+name+'"\n  structure Program = BenchEventFn (Bench'+policy+')\n  structure Driver = BenchEventDriverFn (Program)\n  val run = Driver.run\nend\n')
 for profile,repetitions,horizon in [('smoke',1,200),('normal',100,100000),('large',100,500000)]:
  state=(p/(profile+'.stdout')).read_bytes().splitlines()[0]+b'\n';(dest/(profile+'.state')).write_bytes(state)
  (dest/(profile+'.expected')).write_text(str(repetitions)+' '+str(repetitions*14)+' '+state.decode().strip()+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/stream.sml']+['shared/hartel-event-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/hartel/event',str(repetitions)+' '+str(horizon)+' '+profile+'.state',name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'graphs,higher-order,lists-streams,'+mode,profile+'.state','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/event';data.mkdir();shutil.copytree(p/'cases',data/'cases');(data/'.gitattributes').write_text('cases/** -text -whitespace\n')
(root/'tests/benchmarks/event-tests.sml').write_text((p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""'))
script=(root/'tests/benchmarks/check-bspt.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/hartel-event-'+part+'.sml'for part in parts]+['tests/benchmarks/event-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('bspt','event').replace('original geometric commands, signed rational arithmetic, tree demand and batch sharing hold','original event traces, independent clock model, stable ordering and state demand hold');(root/'tests/benchmarks/check-event.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-event-parallel.'").replace("{'atom-lazy','atom-strict'}","{'event-lazy','event-strict'}");(p/'check-parallel.py').write_text(s)
