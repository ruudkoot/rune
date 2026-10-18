from pathlib import Path
import csv,json,shutil
r=Path.cwd();s=r/'examples/benchmarks';p=r/'tests/out/benchmarks/stdlib-trees-originals';up=r/'tests/out/benchmarks/upstreams/sandmark/benchmarks/stdlib'
parts=['map','set','program']
for x in parts:shutil.copy(p/(x+'.sml'),s/'shared'/('ocaml-stdlib-tree-'+x+'.sml'))
with(s/'manifest.tsv').open()as f:q=csv.DictReader(f,delimiter='\t');fields=q.fieldnames;rows=list(q)
profiles=json.loads((p/'profile-results.json').read_text())
names=sorted({x['benchmark']for x in profiles});assert len(names)==11
assert not any(row['benchmark']in names for row in rows)
for name in names:
 d=s/name;d.mkdir();family=name.split('_')[0]
 if name in ['map_iter','set_fold']:
  (d/'upstream').mkdir()
  shutil.copy(up.parent.parent/'LICENSE.md',d/'upstream/LICENSE.md')
  for suffix in ['.ml','.inc']:shutil.copy(up/(family+('_bench.ml'if suffix=='.ml'else'.inc')),d/'upstream')
  (d/'upstream-library').mkdir()
  for file in (p/'library').iterdir():
   if file.name.startswith(family+'.')or file.name in ['debian-copyright','LGPL-2.1']:shutil.copy(file,d/'upstream-library')
  identities=json.loads((p/'dependency-identities.json').read_text())
  identities['files']={'upstream-library/'+Path(path).name:digest for path,digest in identities['files'].items()
    if (d/'upstream-library'/Path(path).name).exists()}
  (d/'DEPENDENCIES.json').write_text(json.dumps(identities,indent=2)+'\\n')
 shutil.copy(p/'upstream-run-plan.json',d/'UPSTREAM-RUN-PLAN.json')
 (d/'.gitattributes').write_text('upstream/** -text -whitespace\nupstream-library/** -text -whitespace\n')
 content='structure Benchmark=struct\n val name="'+name+'"\n structure Program=BenchStdlibTreePrograms\n'
 if family=='map':
  content+=' val entries=Program.mapEntries 10000\n val baseline=Program.denseMapEntries entries\n'
  operation='Program.mapRun name baseline count'
 else:operation='Program.setRun name count'
 cap=1000000 if family=='map'else 50000000
 content+=' fun run[countText]=let val count=BenchInput.between(0,'+str(cap)+')(BenchInput.integer countText)\n in '+operation+' end\n |run _=raise Fail"expected source iteration count"\nend\n'
 (d/'benchmark.sml').write_text(content)
 for row in [x for x in profiles if x['benchmark']==name]:
  profile=row['profile'];(d/(profile+'.expected')).write_text(row['expected']+'\n')
  sources=['shared/input.sml']+['shared/ocaml-stdlib-tree-'+x+'.sml'for x in parts]+[name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'sandmark','benchmarks/stdlib/'+family+'_bench.exe',str(row['iterations']),name+'/'+profile+'.expected',','.join(sources),str(dict(smoke=30,normal=600,large=3600)[profile]),str(dict(smoke=1048576,normal=4194304,large=8388608)[profile]),'stdlib,collections,trees,higher-order,allocation,library-replacement','-','exact','implemented'])))
with(s/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
f=s/'stdlib-cases.tsv'
with f.open()as stream:q=csv.DictReader(stream,delimiter='\t');fields=q.fieldnames;cases=list(q)
changed=0
for row in cases:
 if row['benchmark']in names:
  assert row['implementation']=='planned';row['implementation']='implemented'
  row['reason']='portable source selector imported with pinned OCaml AVL algorithms, original observations, independent ordered-content models and explicit consumer/identity/comparison adapters'
  changed+=1
assert changed==11
with f.open('w')as stream:w=csv.DictWriter(stream,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(cases)
for filename in ['stdlib-tree-tests.sml','stdlib-tree-program-tests.sml']:
 source=p/('tests.sml'if filename=='stdlib-tree-tests.sml'else'program-tests.sml');shutil.copy(source,r/'tests/benchmarks'/filename)
script=(r/'tests/benchmarks/check-rewrite.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml']+['examples/benchmarks/shared/ocaml-stdlib-tree-'+x+'.sml'for x in parts]+['tests/benchmarks/stdlib-tree-tests.sml','tests/benchmarks/stdlib-tree-program-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
a=script.index('for file in ');b=script.index('\nstatus=0',a);script=script[:a]+': > "$out/data.txt"'+script[b:]
script=script.replace('rewrite-checks','stdlib-trees-checks').replace('bench-rewrite','bench-stdlib-trees')
script=script.replace('--program-data "$root/tests/benchmarks/data/rewrite" \\\n      --program-data-list "$out/data.txt" ','')
script=script.replace('original completion theory, independent free-group forms, substitutions and demand checks hold','original AVL shapes, independent contents and all selector observations agree')
(r/'tests/benchmarks/check-stdlib-trees.sh').write_text(script)
script=(r/'tests/out/benchmarks/atom-originals/check-parallel.py').read_text().replace("prefix='final-atom-parallel.'","prefix='final-stdlib-trees-parallel.'").replace("{'atom-lazy','atom-strict'}",repr(set(names)))
(p/'check-parallel.py').write_text(script)
