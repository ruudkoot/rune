from pathlib import Path
import csv,hashlib,json,shutil
root=Path.cwd();p=root/'tests/out/benchmarks/gg-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/real/gg'
for local,public in [('core.sml','nofib-gg-core.sml'),('graphics.sml','nofib-gg-graphics.sml'),('graphs.sml','nofib-gg.sml'),('checker.sml','nofib-gg-check.sml'),('driver.sml','nofib-gg-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('gg-')for r in rows)
sources=['input','lazy','suspend','stream','finite-binary32','nofib-gg-core','nofib-gg-graphics','nofib-gg','nofib-gg-check','nofib-gg-driver']
for kind in ['activity','spark','pool']:
 for mode,policy in [('lazy','Need'),('strict','Strict')]:
  name=('gg'if kind=='activity'else'gg-'+kind)+'-'+mode;dest=suite/name;dest.mkdir()
  if name=='gg-lazy':shutil.copytree(up,dest/'upstream',ignore=shutil.ignore_patterns('*.o','*.hi','original','observer','*.rbc'))
  (dest/'.gitattributes').write_text('upstream/** -text -whitespace\n*.ps -text -whitespace\n')
  (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Driver = BenchGGDriverFn (Bench{policy})
  val run = Driver.run "{kind}"
end
''')
  for profile,repeats,inputName in [('smoke',1,'gg.faststdin'),('normal',500,'gg.stdin'),('large',1500,'gg.slowstdin')]:
   shutil.copy(up/inputName,dest/inputName);shutil.copy(p/(kind+'-'+profile+'.ps'),dest/(profile+'.ps'))
   lineCount=len((p/(kind+'-'+profile+'.ps')).read_bytes().splitlines())
   (dest/(profile+'.expected')).write_text(f'{repeats}:{repeats*lineCount}\n')
   rows.append(dict(zip(fields,[name,profile,'nofib','real/gg',f'{repeats} {inputName} {profile}.ps landscape -',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'parsing,graphs,numerical,higher-order,lists-streams,'+mode,inputName+','+profile+'.ps','checked-numerical','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/gg';data.mkdir()
for profile,inputName in [('smoke','gg.faststdin'),('normal','gg.stdin'),('large','gg.slowstdin')]:
 shutil.copy(up/inputName,data/inputName);shutil.copy(p/(profile+'.rows'),data/(profile+'.rows'))
 for kind in['activity','spark','pool','eps','portrait']:shutil.copy(p/(kind+'-'+profile+'.ps'),data/(kind+'-'+profile+'.ps'))
shutil.copy(p/'extra.trace',data/'extra.trace')
for kind in['activity','spark','pool']:shutil.copy(p/(kind+'-extra.ps'),data/(kind+'-extra.ps'))
(data/'.gitattributes').write_text('*.ps -text -whitespace\n')
s=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""').replace('"source/"^file','file').replace('base^"source/"^file','base^file').replace('read"source/gg.faststdin"','read"gg.faststdin"').replace('base^"source/gg.stdin"','base^"gg.stdin"').replace('base^"source/gg.faststdin"','base^"gg.faststdin"')
assert 'source/'not in s
(root/'tests/benchmarks/gg-tests.sml').write_text(s)
script=(root/'tests/benchmarks/check-pic.sh').read_text().replace('pic','gg')
script=script.replace('examples/benchmarks/shared/nofib-gg.sml examples/benchmarks/shared/nofib-gg-driver.sml',
 'examples/benchmarks/shared/stream.sml examples/benchmarks/shared/finite-binary32.sml examples/benchmarks/shared/nofib-gg-core.sml examples/benchmarks/shared/nofib-gg-graphics.sml examples/benchmarks/shared/nofib-gg.sml examples/benchmarks/shared/nofib-gg-check.sml examples/benchmarks/shared/nofib-gg-driver.sml').replace('source meshes, particle states, numerical results and demand checks hold','source traces, graph modes, numeric PostScript checks and demand checks hold')
(root/'tests/benchmarks/check-gg.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-gg-parallel.'").replace("{'atom-lazy','atom-strict'}","{'gg-lazy','gg-strict','gg-spark-lazy','gg-spark-strict','gg-pool-lazy','gg-pool-strict'}")
(p/'check-parallel.py').write_text(s)
# The reporter invokes all three graph modes; it is an orchestration script.
f=suite/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;rows=list(r)
for path in['report','example/report']:
 source=up/path
 rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','real/gg','real/gg/'+path,'gg-report'+('-example'if path.startswith('example')else''),'shell','historical report orchestration','not separately stated',hashlib.sha256(source.read_bytes()).hexdigest(),'exclude','byte-identical report scripts invoke activity, spark and pool modes then latex/dvips and remove temporary products; those three computational modes are imported separately, while document orchestration is outside the runnable benchmark kernels','no separate individual notice stated; retain as provenance'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
# Explicitly approve only the immutable compressed source DATA for payload scans.
record=json.loads((p/'compressed-data.json').read_text())
record['repository_path']='examples/benchmarks/gg-lazy/upstream/gg.stdin-2.Z'
(p/'binary-source-data-allowlist.json').write_text(json.dumps([record],indent=2)+'\n')
