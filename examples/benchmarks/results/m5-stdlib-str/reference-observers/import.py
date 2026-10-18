from pathlib import Path
import csv,json,shutil,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/stdlib-str-originals';up=p.parent/'upstreams/sandmark/benchmarks/stdlib'
profiles=json.loads((p/'profile-results.json').read_text());names=sorted({r['benchmark']for r in profiles})
shutil.copy(p/'str.sml',suite/'shared/ocaml-stdlib-str.sml')
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
config=json.loads((up.parent.parent/'run_config.json').read_text())
entries=[dict(index=i,entry=x)for i,x in enumerate(config['benchmarks'])if x['executable']=='benchmarks/stdlib/str_bench.exe']
published={}
for entry in entries:
 for r in entry['entry']['runs']:
  name,n=r['params'].split();assert name not in published;published[name]=int(n)
assert set(names)==set(published)
plan=dict(run_config_sha256=hashlib.sha256((up.parent.parent/'run_config.json').read_bytes()).hexdigest(),entries=entries)
(p/'upstream-run-plan.json').write_text(json.dumps(plan,indent=2)+'\n')
for name in names:
 d=suite/name;d.mkdir();ps=[r for r in profiles if r['benchmark']==name]
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n fun run[countText]=let val count=BenchInput.between(0,'+str(max(r['iterations']for r in ps))+')(BenchInput.integer countText)\n in BenchStdlibStr.run name count end\n |run _=raise Fail"expected source iteration count"\nend\n')
 (d/'UPSTREAM-RUN-PLAN.json').write_text(json.dumps(plan,indent=2)+'\n')
 if name=='str_regexp':
  (d/'upstream').mkdir()
  for file in ['str_bench.ml','str.inc']:shutil.copy(up/file,d/'upstream')
  shutil.copy(up.parent.parent/'LICENSE.md',d/'upstream/LICENSE.md');shutil.copy(up/'dune',d/'upstream/dune')
  shutil.copytree(p/'library',d/'upstream-library')
  data=json.loads((p/'dependency-identities.json').read_text());data['files']={'upstream-library/'+Path(k).name:v for k,v in data['files'].items()}
  (d/'DEPENDENCIES.json').write_text(json.dumps(data,indent=2)+'\n')
  (d/'.gitattributes').write_text('upstream/** -text -whitespace\nupstream-library/** -text -whitespace\n')
 for row in ps:
  profile=row['profile'];(d/(profile+'.expected')).write_text(row['expected']+'\n')
  sources=['shared/input.sml','shared/ocaml-stdlib-text-input.sml','shared/ocaml-stdlib-text.sml','shared/ocaml-stdlib-text-program.sml','shared/sandmark-regexredux-str.sml','shared/ocaml-stdlib-str.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'sandmark','benchmarks/stdlib/str_bench.exe',str(row['iterations']),name+'/'+profile+'.expected',','.join(sources),str(dict(smoke=30,normal=600,large=3600)[profile]),str(dict(smoke=1048576,normal=4194304,large=8388608)[profile]),'stdlib,text,regex,allocation,library-replacement','-','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
file=suite/'stdlib-cases.tsv'
with file.open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;cases=list(r)
for row in cases:
 if row['benchmark']in names:
  assert row['implementation']=='planned';row['implementation']='implemented';row['reason']='portable literal Str fragment with original library observations, partial matching, match state and source splitting semantics; internal OCaml engine replacement is explicit'
with file.open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(cases)
shutil.copy(p/'tests.sml',root/'tests/benchmarks/stdlib-str-tests.sml')
script=(root/'tests/benchmarks/check-stdlib-text.sh').read_text()
a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/ocaml-stdlib-text-input.sml','examples/benchmarks/shared/ocaml-stdlib-text.sml','examples/benchmarks/shared/ocaml-stdlib-text-program.sml','examples/benchmarks/shared/sandmark-regexredux-str.sml','examples/benchmarks/shared/ocaml-stdlib-str.sml','tests/benchmarks/stdlib-str-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('stdlib-text-checks','stdlib-str-checks').replace('bench-stdlib-text','bench-stdlib-str')
script=script.replace('original text operations, independent byte/word models and complete value checks agree','original Str operations, match state and literal models agree')
(root/'tests/benchmarks/check-stdlib-str.sh').write_text(script)
script=(p.parent/'stdlib-text-originals/check-parallel.py').read_text();a=script.index("if row['benchmark']in");b=script.index("and row['profile']",a);script=script[:a]+"if row['benchmark']in"+repr(set(names))+script[b:]
(p/'check-parallel.py').write_text(script.replace('final-stdlib-text-parallel.','final-stdlib-str-parallel.'))
(p/'published-counts.json').write_text(json.dumps(published,indent=2)+'\n')
print('Imported',len(names),'selectors;',len(profiles),'profiles')
