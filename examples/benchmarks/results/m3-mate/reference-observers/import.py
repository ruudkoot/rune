from pathlib import Path
import csv,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/mate-originals'
parts=['board','move','solution']
for part in parts:shutil.copy(p/(part+'.sml'),suite/'shared'/('nofib-mate-'+part+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in{'mate-lazy','mate-strict'}for r in rows)
for mode,flag in [('lazy','false'),('strict','true')]:
 name='mate-'+mode;dest=suite/name;dest.mkdir();(dest/'runtime_files').mkdir()
 if mode=='lazy':shutil.copytree(p/'source',dest/'upstream',ignore=shutil.ignore_patterns('*.o','*.hi','original','build.log'))
 (dest/'.gitattributes').write_text('upstream/** -text -whitespace\nruntime_files/** -text -whitespace\n*.solution -text -whitespace\n')
 (dest/'benchmark.sml').write_text('structure Benchmark =\nstruct\n  val name = "'+name+'"\n  structure Program = BenchMateFn (struct val eagerMoves = '+flag+' end)\n  val run = Program.run\nend\n')
 for profile,problem,reference in [('smoke','simple','smoke-small.stdout'),('normal','kohtz','normal.stdout'),('large','holzhausen','large.stdout')]:
  inp='runtime_files/'+problem+'.prob';shutil.copy(p/'source'/inp,dest/inp)
  expected=profile+'.solution';shutil.copy(p/reference,dest/expected)
  (dest/(profile+'.expected')).write_text(str((p/reference).stat().st_size)+'\n')
  sources=['shared/input.sml','shared/lazy.sml','shared/stream.sml']+['shared/nofib-mate-'+part+'.sml'for part in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'nofib','spectral/mate',inp+' '+expected,name+'/'+profile+'.expected',','.join(sources),str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'search,graphs,lists-streams,'+mode,inp+','+expected,'exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/mate';data.mkdir();shutil.copytree(p/'cases',data/'cases');shutil.copy(p/'smoke-small.stdout',data/'smoke-small.stdout')
(data/'.gitattributes').write_text('cases/** -text -whitespace\nsmoke-small.stdout -text -whitespace\n')
(root/'tests/benchmarks/mate-tests.sml').write_text((p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""'))
script=(root/'tests/benchmarks/check-bspt.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/stream.sml']+['examples/benchmarks/shared/nofib-mate-'+part+'.sml'for part in parts]+['tests/benchmarks/mate-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:];script=script.replace('bspt','mate').replace('original geometric commands, signed rational arithmetic, tree demand and batch sharing hold','original chess moves, complete solutions, short-circuit search and persistent boards hold');(root/'tests/benchmarks/check-mate.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-mate-parallel.'").replace("{'atom-lazy','atom-strict'}","{'mate-lazy','mate-strict'}");(p/'check-parallel.py').write_text(s)
print('registered mate variants')
