from pathlib import Path
import csv,shutil,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/multiplier-originals';up=root/'tests/out/benchmarks/pinned/nofib/spectral/multiplier'
for part in ['kernel','driver']:shutil.copy(p/(part+'.sml'),suite/'shared'/('nofib-multiplier-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('multiplier-')for r in rows)
for consumer in ['trace','count']:
 for mode,flag in [('lazy','false'),('strict','true')]:
  name='multiplier-'+('count-'if consumer=='count'else'')+mode;dest=suite/name;dest.mkdir()
  if consumer=='trace'and mode=='lazy':shutil.copytree(up,dest/'upstream')
  (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n*.trace -text -whitespace\n')
  method='runCount'if consumer=='count'else'run'
  (dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "'+name+'"\n  structure Program = BenchMultiplierFn (struct val eagerBinary = '+flag+' end)\n  structure Driver = BenchMultiplierDriverFn (Program)\n  val run = Driver.'+method+'\nend\n')
  for profile,width,cycles in [('smoke',32,16),('normal',256,2000),('large',512,2000)]:
   file=profile+('.count'if consumer=='count'else'.trace')
   source=p/'cases'/(str(width)+'-'+str(cycles)+'.count')if consumer=='count'else p/('smoke-short.trace'if profile=='smoke'else profile+'.stdout')
   shutil.copy(source,dest/file)
   value=int(source.read_text())if consumer=='count'else source.stat().st_size
   (dest/(profile+'.expected')).write_text(str(width)+' '+str(cycles)+' '+str(value)+'\n')
   sources=['shared/input.sml','shared/lazy.sml','shared/stream.sml','shared/nofib-multiplier-kernel.sml','shared/nofib-multiplier-driver.sml',name+'/benchmark.sml','shared/main.sml']
   rows.append(dict(zip(fields,[name,profile,'nofib','spectral/multiplier',str(width)+' '+str(cycles)+' '+file,name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'circuits,higher-order,lists-streams,word64,'+mode,file,'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/multiplier';data.mkdir();shutil.copytree(p/'cases',data/'cases');shutil.copy(p/'smoke-short.trace',data/'smoke-short.trace')
(data/'.gitattributes').write_text('cases/** -text -whitespace\n*.trace -text -whitespace\n')
(root/'tests/benchmarks/multiplier-tests.sml').write_text((p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""'))
script=(root/'tests/benchmarks/check-bspt.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/stream.sml','examples/benchmarks/shared/nofib-multiplier-kernel.sml','examples/benchmarks/shared/nofib-multiplier-driver.sml','tests/benchmarks/multiplier-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('bspt','multiplier').replace('original geometric commands, signed rational arithmetic, tree demand and batch sharing hold','original traces and ready counts, independent clock models and gate demand hold');(root/'tests/benchmarks/check-multiplier.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-multiplier-parallel.'").replace("{'atom-lazy','atom-strict'}","{'multiplier-lazy','multiplier-strict','multiplier-count-lazy','multiplier-count-strict'}");(p/'check-parallel.py').write_text(s)
f=suite/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');keys=r.fieldnames;variants=list(r)
path='spectral/multiplier/Main.hs';variants.append(dict(zip(keys,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','spectral/multiplier',path,'multiplier-count','Haskell','inactive count-only simulation driver',"John T. O'Donnell",hashlib.sha256((up/'Main.hs').read_bytes()).hexdigest(),'import','ported separately as multiplier-count-lazy/strict; runMult sums ready without observing product registers, so its demand excludes the product adder; preserve this source consumer and all provenance rather than silently replacing verbose traceMult','Copyright (c) 1992 John T. O\'Donnell; full original notice retained'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=keys,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(variants)
