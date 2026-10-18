from pathlib import Path
import csv,json,shutil,hashlib
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/stdlib-text-originals';up=p.parent/'upstreams/sandmark/benchmarks/stdlib'
profiles=json.loads((p/'profile-results.json').read_text());names=sorted({x['benchmark']for x in profiles})
assert len(names)==25
for local,public in [('input','ocaml-stdlib-text-input'),('text','ocaml-stdlib-text'),('program','ocaml-stdlib-text-program')]:
 shutil.copy(p/(local+'.sml'),suite/'shared'/(public+'.sml'))
with(suite/'manifest.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=list(r)
assert not any(r['benchmark']in names for r in rows)
for name in names:
 d=suite/name;d.mkdir();family=name.split('_')[0];ps=[x for x in profiles if x['benchmark']==name]
 content='structure Benchmark=struct\n val name="'+name+'"\n structure P=BenchStdlibTextPrograms\n'
 if family=='bytes':content+=' val input=BenchStdlibText.Bytes.ofString BenchStdlibText.text\n'
 operation='P.runBytes input name count'if family=='bytes'else'P.runString name count'
 content+=' fun run[countText]=let val count=BenchInput.between(0,'+str(max(x['iterations']for x in ps))+')(BenchInput.integer countText)\n in '+operation+' end\n |run _=raise Fail"expected source iteration count"\nend\n'
 (d/'benchmark.sml').write_text(content)
 shutil.copy(p/'upstream-run-plan.json',d/'UPSTREAM-RUN-PLAN.json')
 if name in ['bytes_get','string_get']:
  (d/'upstream').mkdir();shutil.copy(up.parent.parent/'LICENSE.md',d/'upstream/LICENSE.md');shutil.copy(up/'dune',d/'upstream/dune')
  for file in [family+'_bench.ml',family+'.inc']:shutil.copy(up/file,d/'upstream')
  (d/'upstream-library').mkdir()
  for file in(p/'library').iterdir():
   if file.name.startswith(family+'.')or file.name in ['debian-copyright','LGPL-2.1','LICENSE']:shutil.copy(file,d/'upstream-library')
  data=json.loads((p/'dependency-identities.json').read_text())
  data['files']={'upstream-library/'+Path(k).name:v for k,v in data['files'].items()if(d/'upstream-library'/Path(k).name).exists()}
  (d/'DEPENDENCIES.json').write_text(json.dumps(data,indent=2)+'\n')
  shutil.copy(p/'text.reference',d/'upstream/input.reference')
  shutil.copy(p/'text-identities.json',d/'INPUT-IDENTITY.json')
  (d/'.gitattributes').write_text('upstream/** -text -whitespace\nupstream-library/** -text -whitespace\n')
 for x in ps:
  profile=x['profile'];(d/(profile+'.expected')).write_text(x['expected']+'\n')
  sources=['shared/input.sml','shared/ocaml-stdlib-text-input.sml','shared/ocaml-stdlib-text.sml','shared/ocaml-stdlib-text-program.sml',name+'/benchmark.sml','shared/main.sml']
  rows.append(dict(zip(fields,[name,profile,'sandmark','benchmarks/stdlib/'+family+'_bench.exe',str(x['iterations']),name+'/'+profile+'.expected',','.join(sources),str(dict(smoke=30,normal=600,large=3600)[profile]),str(dict(smoke=1048576,normal=4194304,large=8388608)[profile]),'stdlib,text,bytes,allocation,library-replacement','-','exact','implemented'])))
with(suite/'manifest.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
file=suite/'stdlib-cases.tsv'
with file.open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;cases=list(r)
changed=0
for row in cases:
 if row['benchmark']in names:
  assert row['implementation']=='planned';row['implementation']='implemented'
  row['reason']='portable source operation with fixed original text, reviewed OCaml library fragment, full result checks and independently reviewed original observations'
  if row['reachable']=='false':row['reason']+='; defined upstream function exported directly because the original CLI omits this selector'
  changed+=1
assert changed==25
with file.open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(cases)
for local,public in [('tests','stdlib-text-tests'),('program-tests','stdlib-text-program-tests')]:shutil.copy(p/(local+'.sml'),root/'tests/benchmarks'/(public+'.sml'))
script=(root/'tests/benchmarks/check-stdlib-trees.sh').read_text()
a=script.index('for source in ');b=script.index('; do',a)
files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/ocaml-stdlib-text-input.sml','examples/benchmarks/shared/ocaml-stdlib-text.sml','examples/benchmarks/shared/ocaml-stdlib-text-program.sml','tests/benchmarks/stdlib-text-tests.sml','tests/benchmarks/stdlib-text-program-tests.sml','tests/basis/finish.sml']
script=script[:a]+'for source in '+' '.join(files)+script[b:]
script=script.replace('stdlib-trees','stdlib-text').replace('original AVL shapes, independent contents and all selector observations agree','original text operations, independent byte/word models and complete value checks agree')
(root/'tests/benchmarks/check-stdlib-text.sh').write_text(script)
script=(p.parent/'stdlib-trees-originals/check-parallel.py').read_text();a=script.index("if row['benchmark']in");b=script.index("and row['profile']",a)
script=script[:a]+"if row['benchmark']in"+repr(set(names))+script[b:]
script=script.replace('final-stdlib-trees-parallel.','final-stdlib-text-parallel.')
(p/'check-parallel.py').write_text(script)
print('Imported',len(names),'selectors and',len(profiles),'profiles')
