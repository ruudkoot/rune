from pathlib import Path
import csv,json,shutil
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/stdlib-hashtbl-originals';up=p.parent/'upstreams/sandmark/benchmarks/stdlib'
profiles=json.loads((p/'profile-results.json').read_text());names=sorted({r['benchmark']for r in profiles})
assert len(names)==14
for source,public in [('hash','hash'),('table','hashtbl'),('program','hashtbl-program')]:shutil.copy(p/(source+'.sml'),suite/'shared'/('ocaml-stdlib-'+public+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
for name in names:
 d=suite/name;d.mkdir();ps=[r for r in profiles if r['benchmark']==name]
 (d/'benchmark.sml').write_text('structure Benchmark=struct\n val name="'+name+'"\n fun run[countText]=let val count=BenchInput.between(0,'+str(max(r['iterations']for r in ps))+')(BenchInput.integer countText)\n in BenchStdlibHashtblPrograms.run name count end\n |run _=raise Fail"expected source iteration count"\nend\n')
 shutil.copy(p/'upstream-run-plan.json',d/'UPSTREAM-RUN-PLAN.json')
 if name=='hashtbl_iter':
  (d/'upstream').mkdir()
  for file in ['hashtbl_bench.ml','hashtbl.inc']:shutil.copy(up/file,d/'upstream')
  shutil.copy(up.parent.parent/'LICENSE.md',d/'upstream/LICENSE.md');shutil.copy(up/'dune',d/'upstream/dune')
  shutil.copytree(p/'library',d/'upstream-library')
  data=json.loads((p/'dependency-identities.json').read_text());data['files']={'upstream-library/'+Path(k).name:v for k,v in data['files'].items()}
  (d/'DEPENDENCIES.json').write_text(json.dumps(data,indent=2)+'\n')
  (d/'.gitattributes').write_text('upstream/** -text -whitespace\nupstream-library/** -text -whitespace\n')
 for row in ps:
  profile=row['profile'];(d/(profile+'.expected')).write_text(row['expected']+'\n')
  sources=['shared/input.sml','shared/ocaml-stdlib-hash.sml','shared/ocaml-stdlib-hashtbl.sml','shared/ocaml-stdlib-hashtbl-program.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'sandmark','benchmarks/stdlib/hashtbl_bench.exe',str(row['iterations']),name+'/'+profile+'.expected',','.join(sources),str(dict(smoke=30,normal=600,large=3600)[profile]),str(dict(smoke=1048576,normal=4194304,large=8388608)[profile]),'stdlib,hashing,mutable-collections,allocation,modular-arithmetic,library-replacement','-','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
file=suite/'stdlib-cases.tsv'
with file.open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;cases=list(r)
for row in cases:
 if row['benchmark']in names:
  assert row['implementation']=='planned';row['implementation']='implemented';row['reason']='pinned OCaml bucket/resize and fixed-domain MurmurHash3 algorithms, explicit signed63 filter arithmetic, preserved empty find tables and inclusive loops, original layout/result observations and independent models'
with file.open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(cases)
for source,public in [('tests','stdlib-hashtbl-tests'),('program-tests','stdlib-hashtbl-program-tests')]:shutil.copy(p/(source+'.sml'),root/'tests/benchmarks'/(public+'.sml'))
script=(root/'tests/benchmarks/check-stdlib-trees.sh').read_text();a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/ocaml-stdlib-hash.sml','examples/benchmarks/shared/ocaml-stdlib-hashtbl.sml','examples/benchmarks/shared/ocaml-stdlib-hashtbl-program.sml','tests/benchmarks/stdlib-hashtbl-tests.sml','tests/benchmarks/stdlib-hashtbl-program-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('stdlib-trees-checks','stdlib-hashtbl-checks').replace('bench-stdlib-trees','bench-stdlib-hashtbl').replace('original AVL shapes, independent contents and all selector observations agree','original hash/bucket layouts, numeric widths and selector observations agree')
(root/'tests/benchmarks/check-stdlib-hashtbl.sh').write_text(script)
script=(p.parent/'stdlib-trees-originals/check-parallel.py').read_text();a=script.index("if row['benchmark']in");b=script.index("and row['profile']",a);script=script[:a]+"if row['benchmark']in"+repr(set(names))+script[b:]
(p/'check-parallel.py').write_text(script.replace('final-stdlib-trees-parallel.','final-stdlib-hashtbl-parallel.'))
print('Imported',len(names),'selectors;',len(profiles),'profiles')
