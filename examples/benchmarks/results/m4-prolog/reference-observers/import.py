from pathlib import Path
import csv,shutil,hashlib
root=Path.cwd();p=root/'tests/out/benchmarks/prolog-originals';suite=root/'examples/benchmarks';up=root/'tests/out/benchmarks/pinned/nofib/real/prolog'
for local,public in [('parse.sml','nofib-prolog-parse.sml'),('kernel.sml','nofib-prolog.sml'),('driver.sml','nofib-prolog-driver.sml')]:shutil.copy(p/local,suite/'shared'/public)
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark'].startswith('prolog-')for r in rows)
sources=['input','lazy','suspend','stream','nofib-prolog-parse','nofib-prolog','nofib-prolog-driver']
for engine,tree in [('stack',False),('pure',True)]:
 for mode,policy in [('lazy','Need'),('strict','Strict')]:
  name=('prolog-tree'if tree else'prolog')+'-'+mode;dest=suite/name;dest.mkdir()
  if name=='prolog-lazy':shutil.copytree(up,dest/'upstream')
  (dest/'benchmark.sml').write_text(f'''structure Benchmark =
struct
  val name = "{name}"
  structure Kernel = BenchPrologFn (Bench{policy})
  structure Driver = BenchPrologDriverFn (Kernel)
  val run = Driver.run {str(tree).lower()}
end
''')
  shutil.copy(up/'runtime_files/stdlib',dest/'stdlib')
  if name=='prolog-lazy':(dest/'.gitattributes').write_text('upstream/** -text -whitespace\n')
  for profile,repeats,inputFile in [('smoke',1,'prolog.faststdin'),('normal',200,'prolog.stdin'),('large',200,'prolog.slowstdin')]:
   shutil.copy(up/inputFile,dest/(profile+'.input'));shutil.copy(p/engine/(profile+'.text'),dest/(profile+'.text'))
   data=(dest/(profile+'.text')).read_bytes();value=0
   for c in data:value=(31*value+c)%(2**64)
   (dest/(profile+'.expected')).write_text(f'{repeats}:{value:X}\n')
   rows.append(dict(zip(fields,[name,profile,'nofib','real/prolog',f'{repeats} stdlib {profile}.input {profile}.text',f'{name}/{profile}.expected',','.join('shared/'+s+'.sml'for s in sources)+f',{name}/benchmark.sml,shared/main.sml',str({'smoke':30,'normal':600,'large':3600}[profile]),str({'smoke':1048576,'normal':4194304,'large':8388608}[profile]),'parsing,symbolic-search,higher-order,lists-streams,'+mode,'stdlib,'+profile+'.input,'+profile+'.text','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
data=root/'tests/benchmarks/data/prolog';data.mkdir()
for file in p.glob('*.input'):shutil.copy(file,data/file.name)
for file in p.glob('*-stack.text'):shutil.copy(file,data/file.name)
for file in p.glob('*-pure.text'):shutil.copy(file,data/file.name)
for engine in ['stack','pure']:
 for profile in ['smoke','normal','large']:shutil.copy(p/engine/(profile+'.text'),data/(engine+'-'+profile+'.text'))
for profile,source in [('smoke','prolog.faststdin'),('normal','prolog.stdin'),('large','prolog.slowstdin')]:shutil.copy(up/source,data/(profile+'.input'))
shutil.copy(up/'runtime_files/stdlib',data/'stdlib')
s=(p/'tests.sml').read_text().replace('val base="'+str(p)+'/"','val base=""').replace('read"source/runtime_files/stdlib"','read"stdlib"').replace('"source/"^input','input')
s=s.replace('("smoke","prolog.faststdin"),("normal","prolog.stdin"),("large","prolog.slowstdin")','("smoke","smoke.input"),("normal","normal.input"),("large","large.input")')
s=s.replace('engine^"/"^profile^".text"','engine^"-"^profile^".text"').replace('read"source/prolog.faststdin"','read"smoke.input"').replace('read"stack/smoke.text"','read"stack-smoke.text"')
(root/'tests/benchmarks/prolog-tests.sml').write_text(s)
script=(root/'tests/benchmarks/check-pic.sh').read_text().replace('pic','prolog').replace(
 'examples/benchmarks/shared/nofib-prolog.sml examples/benchmarks/shared/nofib-prolog-driver.sml',
 'examples/benchmarks/shared/stream.sml examples/benchmarks/shared/nofib-prolog-parse.sml examples/benchmarks/shared/nofib-prolog.sml examples/benchmarks/shared/nofib-prolog-driver.sml').replace(
 'source meshes, particle states, numerical results and demand checks hold','source transcripts, parser alternatives, unification, cut and demand checks hold')
(root/'tests/benchmarks/check-prolog.sh').write_text(script)
s=(root/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-prolog-parallel.'").replace("{'atom-lazy','atom-strict'}","{'prolog-lazy','prolog-strict','prolog-tree-lazy','prolog-tree-strict'}")
(p/'check-parallel.py').write_text(s)
# Engine.hs is the selected entrypoint; retain StackEngine.hs's exact duplicate.
f=suite/'source-variants.tsv'
with f.open()as stream:r=csv.DictReader(stream,delimiter='\t');fields=r.fieldnames;rows=list(r)
for filename,name,disposition,reason in [
 ('StackEngine.hs','prolog-stack','duplicate','byte-identical to the active Engine.hs at the pinned revision; share prolog-lazy/prolog-strict implementations and retain both source paths'),
 ('PureEngine.hs','prolog-tree','import','explicit memoized proof-tree engine, without the stack engines cut predicate; ported as prolog-tree-lazy/prolog-tree-strict with its own transcripts')]:
 source=up/filename
 rows.append(dict(zip(fields,['nofib','b7391df4540ac8b11b35e1b2e2c15819b5171798','real/prolog','real/prolog/'+filename,name,'Haskell','alternative inference engine','Mark P. Jones',hashlib.sha256(source.read_bytes()).hexdigest(),disposition,reason,'authorship header retained; no separate individual redistribution grant stated'])))
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
