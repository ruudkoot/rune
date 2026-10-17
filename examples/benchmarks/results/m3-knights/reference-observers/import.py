from pathlib import Path
import csv,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/knights-originals';up=p/'source'
for src,dest in [('kernel.sml','nofib-knights-list.sml'),('array.sml','nofib-knights-array.sml')]:shutil.copy(p/src,suite/'shared'/dest)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('knights-')for r in rows)
for rep in ['list','array']:
 for mode,policy in [('lazy','Need'),('strict','Strict')]:
  name='knights-'+('array-'if rep=='array'else'')+mode;dest=suite/name;dest.mkdir()
  if rep=='list'and mode=='lazy':shutil.copytree(up,dest/'upstream',ignore=shutil.ignore_patterns('*.o','*.hi','original','build.log'))
  (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n*.tour -text -whitespace\n')
  functor='BenchKnightsArrayFn'if rep=='array'else'BenchKnightsFn'
  (dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "'+name+'"\n  structure Program = '+functor+' (Bench'+policy+')\n  val run = Program.run\nend\n')
  for profile,size,repeats in [('smoke',8,1),('normal',14,100),('large',20,100)]:
   reference=p/(str(size)+'-1'+('.array-tour'if rep=='array'else'.tour'))
   file=profile+'.tour';shutil.copy(reference,dest/file)
   (dest/(profile+'.expected')).write_text(str(repeats)+' '+str(repeats*reference.stat().st_size)+'\n')
   sources=['shared/input.sml','shared/lazy.sml','shared/suspend.sml','shared/stream.sml','shared/nofib-knights-'+rep+'.sml',name+'/benchmark.sml','shared/main.sml']
   rows.append(dict(zip(fields,[name,profile,'nofib','spectral/knights',str(repeats)+' '+str(size)+' 1 '+file,name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'search,higher-order,lists-streams,'+mode,file,'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/knights';data.mkdir()
for f in list(p.glob('*.tour'))+list(p.glob('*.array-tour')):shutil.copy(f,data/f.name)
(data/'.gitattributes').write_text('*.tour -text -whitespace\n*.array-tour -text -whitespace\n')
for source,dest in [('tests.sml','knights-tests.sml'),('array-tests.sml','knights-array-tests.sml')]:
 s=(p/source).read_text().replace('val base="'+str(p)+'/"','val base=""');(root/'tests/benchmarks'/dest).write_text(s)
parts=['list','array']
for rep in parts:
 script=(root/'tests/benchmarks/check-linear.sh').read_text();name='knights'+('-array'if rep=='array'else'')
 a=script.index('for source in ');b=script.index('; do',a)
 sources=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/stream.sml','examples/benchmarks/shared/nofib-knights-'+rep+'.sml','tests/benchmarks/'+name+'-tests.sml','tests/basis/finish.sml']
 script=script[:a]+'for source in '+' '.join(sources)+script[b:]
 script=script.replace('linear',name).replace('tests/benchmarks/data/'+name,'tests/benchmarks/data/knights')
 script=script.replace('original Float block/preconditioner metrics, higher-order demand and text consumers hold','original full tours, independent legality, metadata sharing and persistent boards hold')
 (root/'tests/benchmarks'/('check-'+name+'.sh')).write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-knights-parallel.'").replace("{'atom-lazy','atom-strict'}","{'knights-lazy','knights-strict','knights-array-lazy','knights-array-strict'}")
(p/'check-parallel.py').write_text(s)
print('registered 380 programs/1132 profiles')
