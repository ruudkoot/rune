from pathlib import Path
import csv,hashlib,json,re,shutil,os
root=Path.cwd();p=Path(__file__).resolve().parent
suite=root/'examples/benchmarks';dest=suite/'results/m4-veritas'
scope={'__file__':str(p/'curate.py')};exec((root/'tests/out/benchmarks/m4-anna/curate.py').read_text().split("assert json.loads((p/'acceptance-exit.json')")[0],scope)
scope['p']=p;scope['dest']=dest
copy=scope['copy'];tree=scope['tree'];table=scope['table'];outcome=scope['outcome'];normalize=scope['normalize']
acceptance=json.loads((root/'tests/out/benchmarks/m8/acceptance-exit.json').read_text());assert acceptance['exit']==0
records=json.loads((p/'primary-exits.json').read_text());assert len(records)==4
dest.mkdir(exist_ok=True)
(dest/'.gitattributes').write_text('# Exact source and execution evidence.\n** -whitespace\n')
tree(p,dest/'validation-drivers')
ref=root/'tests/out/benchmarks/nofib-veritas-originals'
tree(ref,dest/'reference-observers')
# Preserve binary request/proof observations losslessly as ASCII hexadecimal.
for f in ref.rglob('*'):
 if not f.is_file()or any(x in ['.git','MLB','.cm']for x in f.parts)or f.suffix in scope['compiled']:continue
 data=f.read_bytes()
 if b'\0'in data and not data.startswith((b'\x7fELF',b'MZ',b'!<arch>\n')):
  target=dest/'reference-observers'/f.relative_to(ref);target=target.with_name(target.name+'.hex')
  target.parent.mkdir(parents=True,exist_ok=True);target.write_text(data.hex()+'\n')
rows=[]
for item in records:
 logfile=Path(item['log']);log=logfile.read_text();run=Path(re.search(r'^BENCH OUTPUT (.+)$',log,re.M)[1])
 for job in sorted(run.iterdir()):
  if not(job/'result.log').exists():continue
  text=(job/'result.log').read_text()
  for match in re.finditer(r'^PROGRAM (?:PASS|FAIL) (\S+)',text,re.M):
   cfg=match[1];program=job/'matrix'/normalize(cfg)/'program';assert program.exists(),str(program)
   saved=dest/'correctness'/item['level']/item['profile']/job.name/normalize(cfg);tree(program,saved)
   for name in ['input','sources.txt','data.txt','result.log']:copy(job/name,saved/('matrix-'+name if name=='result.log'else name))
   def read(name):return(program/name).read_text(errors='replace')if(program/name).exists()else''
   state=outcome(text,cfg,read('stdout'),read('stderr'),read('log'))
   fail_line=text[text.find(match[0]):].splitlines()[0]
   if state!='pass'and 'load 1, exit 124'in fail_line:
    if cfg.startswith('native:smlnj'):state='timeout-phase-unclassified'
    elif cfg.startswith(('native:mlton','native:mlkit')):state='compile-timeout'
   rows.append([job.name,item['profile'],item['level'],'host-default'if cfg.startswith('native:')else item['level'],cfg,state,str(saved.relative_to(suite))])
assert len(rows)==56,len(rows)
assert sum(r[5]=='pass'for r in rows if r[4].startswith('rune'))==32
table(dest/'correctness.tsv',['benchmark','profile','requested_level','effective_options','configuration','status','artifact_directory'],rows)
initial=root/'tests/out/benchmarks/nofib-veritas-checks.iCKlOJ'
retry_rune=root/'tests/out/benchmarks/nofib-veritas-checks.pD7HDW'
retry_native=root/'tests/out/benchmarks/nofib-veritas-checks.TKEZKE'
semrows=[];attempts=[]
for epoch,run in [('before-fixture-list',initial),('fixture-rune-retry',retry_rune),('fixture-native-retry',retry_native)]:
 for level in ['O0','O2']:
  copy(run/(level+'.log'),dest/'semantics'/epoch/(level+'.log'))
  if not(run/level).exists():continue
  for cfg in sorted((run/level).iterdir()):
   program=cfg/'program'
   if not program.exists():continue
   stdout=(program/'stdout').read_text(errors='replace')if(program/'stdout').exists()else''
   passed=len(re.findall(r'^PASS ',stdout,re.M));failed=len(re.findall(r'^FAIL ',stdout,re.M))
   complete=bool(re.search(r'^SUMMARY 218 checks, 0 failed$',stdout,re.M))
   saved=dest/'semantics'/epoch/level/cfg.name;tree(program,saved)
   final_data=(program/'tests/benchmarks/data/nofib-veritas/cases/FILES').exists()
   # Program cwd is the fresh fixture copy; inspect its actual data, not the current repository.
   if not final_data:final_data=any(f.is_file()for f in program.glob('**/cases/FILES'))
   canonical=epoch!='before-fixture-list'or cfg.name in ['native-smlnj32-110.99.9','native-smlnj-dev-2026.2','native-polyml-5.9.2','native-mlkit-4.7.23']
   status='pass'if complete and not failed else'assertion-failure'if failed else'compile-timeout'if'compile timed out'in((run/(level+'.log')).read_text())and cfg.name.startswith('native-mlkit')else'incomplete'
   row=[epoch,level,cfg.name,status,passed,failed,str(complete).lower(),str(final_data).lower(),str(saved.relative_to(suite))]
   attempts.append(row)
   if canonical:semrows.append(row)
assert len(semrows)==14 and sum(r[4]for r in semrows)==13*218 and sum(r[5]for r in semrows)==0,(len(semrows),semrows)
header=['epoch','requested_level','configuration','status','passed','failed','complete','has_case_list','artifact_directory']
table(dest/'semantics.tsv',header,semrows);table(dest/'semantic-attempts.tsv',header,attempts)
for name in ['veritas-lazy','veritas-strict']:
 guard=json.loads((p/('count-'+name+'.json')).read_text());assert guard['exit']==0 and guard['guard_reason']is None
 text=(p/('count-'+name+'-guard.log')).read_text();assert'COUNT comparisons agree'in text
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',text,re.M)[1]);tree(run,dest/'counts'/name)
for epoch,name in [('before-closed-parser-pairs','serial-native.log'),('final','serial-native-fixed.log')]:
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',(p/name).read_text(),re.M)[1]);tree(run,dest/'fresh-adapter-diagnostics'/epoch)
fresh=list(csv.DictReader((dest/'fresh-adapter-diagnostics/final/samples.tsv').open(),delimiter='\t'))
assert sum(r['phase']=='fresh'and r['status']=='pass'for r in fresh)==4
copy(root/'tests/out/benchmarks/m8/acceptance.log',dest/'acceptance.log')
copy(root/'tests/out/benchmarks/m8/acceptance-subject.json',dest/'acceptance-subject.json')
copy(root/'tests/out/benchmarks/m8/acceptance-exit.json',dest/'acceptance-exit.json')
summary=dict(programs=507,profiles=1473,profile_combinations=56,profile_pass=sum(r[5]=='pass'for r in rows),rune_pass=32,
 semantic_groups=14,semantic_complete=13,semantic_pass=13*218,semantic_fail=0,raw_semantic_groups=len(attempts),
 normal_count_samples=8,fresh_adapter_samples=4,acceptance=acceptance)
(dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
table(dest/'excluded-payloads.tsv',['original_path','bytes','sha256'],sorted(set(scope['skipped'])))
with(dest/'source-identities.tsv').open('w')as f:
 for file in sorted(set(x for r in csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t')if r['benchmark'].startswith('veritas-')for x in r['sources'].split(','))):
  f.write(hashlib.sha256((suite/file).read_bytes()).hexdigest()+'\t'+file+'\n')
print(json.dumps(summary,indent=2))
