from pathlib import Path
import csv,re,shutil,json,hashlib,subprocess
root=Path.cwd();suite=root/'examples/benchmarks';ref=root/'tests/out/benchmarks/nofib-simple-originals'
scope={};exec((root/'tests/out/benchmarks/archive-oct15-wave.py').read_text().split('fib=root/')[0],scope)
compiled={'.rbc','.o','.hi','.exe','.native','.heap','.cmx','.cmi','.cmo','.cmxa','.cma','.a'}
def exclude(directory,names):
 ignored=set()
 for name in names:
  path=Path(directory)/name
  if name in ['work','matrix','MLB','.cm','__pycache__']or path.suffix in compiled:ignored.add(name);continue
  if path.is_file():
   data=path.read_bytes()
   if 0 in data or data.startswith((bytes([127])+b'ELF',b'MZ',b'!<arch>\n')):ignored.add(name)
 return ignored
def copy(src,dst):
 if src.exists():shutil.copytree(src,dst,ignore=exclude,dirs_exist_ok=True)
def table(path,fields,rows):
 with path.open('w')as f:w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(fields);w.writerows(rows)
names=['simple-nofib-lazy','simple-nofib-strict','simple-nofib-report-lazy','simple-nofib-report-strict']
initial=Path(re.search(r'VALIDATION OUTPUT (.+)',(ref/'correctness-final.log').read_text())[1])
smoke=Path(re.search(r'VALIDATION OUTPUT (.+)',(ref/'correctness-smoke-final.log').read_text())[1])
v2=Path(re.search(r'VALIDATION OUTPUT (.+)',(ref/'correctness-final-v2.log').read_text())[1])
final=Path(re.search(r'VALIDATION OUTPUT (.+)',(ref/'correctness-final-v3.log').read_text())[1])
out=scope['archive']('m3-simple-nofib',ref,names,[('correctness-final.log',False),('correctness-smoke-final.log',False),('correctness-final-v2.log',False),('correctness-final-v3.log',False)],0)
attempts=list(csv.DictReader((out/'correctness-attempts.tsv').open(),delimiter='\t'))
assert len(attempts)==392
for row in attempts:
 if row['status']=='pass':continue
 saved=suite/row['artifact_directory']
 stdout=(saved/'stdout').read_text(errors='replace')
 log=(saved/'log').read_text(errors='replace')
 run=next(run for run in [initial,smoke,v2,final]if run.name in row['artifact_directory'])
 level='hosts'if row['optimization']=='host-default'else row['optimization']
 original=run/row['benchmark']/row['profile']/level/'matrix'/row['configuration']/'program'
 if 'incorrect result:'in stdout:
  row['status']='incorrect-result'
 elif any(line.startswith('FAIL ')for line in stdout.splitlines()):
  row['status']='runtime-failure'
 elif 'compile timed out'in log:row['status']='compile-timeout'
 elif 'timed out after'in log:row['status']='timeout'
 elif row['configuration'].startswith('native-mlkit')and not(original/'prog').exists():
  row['status']='compile-memory-limit'if'Cannot allocate memory'in log else'compile-error'
 else:raise AssertionError((row,log[:500],stdout[:500]))
canonical=[r for r in attempts if final.name in r['artifact_directory']]
assert len(canonical)==112
required=sum(r['status']=='pass'for r in canonical)
for filename,rows in [('coverage.tsv',canonical),('correctness-attempts.tsv',attempts),('correctness.tsv',[r for r in canonical if r['status']=='pass'])]:
 with(out/filename).open('w')as f:w=csv.DictWriter(f,fieldnames=list(attempts[0]),delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
(out/'primary-selection.json').write_text(json.dumps({'initial':initial.name,'final_smoke':smoke.name,'canonical_normal_grid':100,'canonical_smoke_grid':8,'canonical_attempts':112,'final_checker':final.name,'all_attempts':392,'passing':required,'scope':'Only final conditioning-aware checker attempts supply canonical coverage. Initial grid-100 smoke and grid-8 point-sum-checker attempts remain development evidence.'},indent=2)+'\n')
counts=[];fresh=0
for name in names:
 log=ref/('count-'+name+'-guard.log');assert 'COUNT comparisons agree'in log.read_text()
 guard=json.loads((ref/('count-'+name+'.json')).read_text());assert guard['exit']==0 and guard['guard_reason']is None
 for suffix in ['.log','.json','-guard.log']:shutil.copy(ref/('count-'+name+suffix),out/('count-'+name+suffix))
 run=Path(re.search(r'BENCH MEASUREMENT (.+)',log.read_text())[1]);dst=out/'counts'/run.name;copy(run,dst)
 with(run/'samples.tsv').open()as f:r=csv.DictReader(f,delimiter='\t');fields=r.fieldnames;rows=[x for x in r if x['phase']=='count']
 assert len(rows)==4 and all(x['status']=='pass'and x['profile']=='normal'for x in rows)
 for row in rows:row['artifact']=str((dst/row['artifact']).relative_to(out))
 counts+=rows
 log=ref/('native-adapter-v3-'+name+'.log');shutil.copy(log,out/log.name)
 initialLog=ref/('native-adapter-'+name+'.log')
 initialRun=Path(re.search(r'BENCH MEASUREMENT (.+)',initialLog.read_text())[1])
 copy(initialRun,out/'development'/'full-grid-adapters'/initialRun.name)
 shutil.copy(initialLog,out/'development'/initialLog.name)
 run=Path(re.search(r'BENCH MEASUREMENT (.+)',log.read_text())[1]);copy(run,out/'native-adapter-diagnostics'/run.name)
 rows=list(csv.DictReader((run/'samples.tsv').open(),delimiter='\t'))
 for row in rows:
  if row['status']!='pass':
   assert row['config'].startswith('native:smlnj-legacy')and row['phase']=='correctness'and row['status']=='incorrect-result'
 selected=[r for r in rows if r['phase']=='fresh'];assert len(selected)in[2,3]and all(r['status']=='pass'for r in selected);fresh+=len(selected)
with(out/'count-samples.tsv').open('w')as f:w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(counts)
shutil.copy(suite/'count-budgets.tsv',out/'count-budget-reference.tsv')
with(out/'count-comparison.log').open('w')as log:subprocess.run(['bin/runevm','build/bench-counts.rbc',str(out/'count-samples.tsv'),str(out/'count-budget-reference.tsv'),'check'],stdout=log,stderr=subprocess.STDOUT,check=True)
summary=[]
for level in ['O0','O2']:
 run=ref/('host-tests-'+level);shutil.copy(ref/('host-tests-'+level+'.log'),out/('semantics-'+level+'.log'));copy(run,out/'semantics'/level)
 for cfg in sorted(run.iterdir()):
  src=cfg/'program'
  if not src.is_dir():continue
  text=(src/'stdout').read_text(errors='replace');passed=sum(line.startswith('PASS ')for line in text.splitlines());failed=sum(line.startswith('FAIL ')for line in text.splitlines())
  expected=None if cfg.name.startswith('native-smlnj-legacy')else 0
  assert passed+failed==108 and(expected is None or failed==expected)
  summary.append([level,cfg.name,108,108,passed,failed,0,'incorrect-result'if failed else'pass'])
assert len(summary)==20
table(out/'semantic-summary.tsv',['level','configuration','planned','completed','passed','failed','unreached','status'],summary)
copy(ref/'legacy-diagnostics',out/'legacy-diagnostics')
shutil.copy(ref/'legacy-diagnostics.log',out/'legacy-diagnostics.log')
for attempt in ['tuple-portability','numeric-portability','aggregate-check-development','boundary-table-development','table-only-development','tuple-total-portability']:
 copy(ref/attempt,out/'development'/attempt)
for attempt in ['default-1','default-2','default-3']:
 log=(ref/'legacy-diagnostics'/attempt/'stdout').read_text()
 assert'REFERENCE-MISMATCH'in log
for attempt in ['nursery64m-1','nursery64m-2','nursery64m-3']:
 log=(ref/'legacy-diagnostics'/attempt/'stderr').read_text()
 assert'unable to allocate minimum size'in log
copy(ref/'total-diagnostics',out/'total-diagnostics')
for name in names:
 oldlog=ref/'aggregate-check-development'/('count-'+name+'.log')
 if 'BENCH MEASUREMENT'not in oldlog.read_text():oldlog=ref/'aggregate-check-development'/('count-'+name+'-guard.log')
 oldrun=Path(re.search(r'BENCH MEASUREMENT (.+)',oldlog.read_text())[1])
 copy(oldrun,out/'development'/'aggregate-check-development'/'counts'/oldrun.name)
for name in names:
 oldlog=ref/'boundary-table-development'/('count-'+name+'-guard.log')
 oldrun=Path(re.search(r'BENCH MEASUREMENT (.+)',oldlog.read_text())[1])
 copy(oldrun,out/'development'/'boundary-table-development'/'counts'/oldrun.name)
 oldlog=ref/'boundary-table-development'/('native-adapter-final-'+name+'.log')
 oldrun=Path(re.search(r'BENCH MEASUREMENT (.+)',oldlog.read_text())[1])
 copy(oldrun,out/'development'/'boundary-table-development'/'native-adapters'/oldrun.name)
observer=out/'reference-observers';observer.mkdir(exist_ok=True)
for file in ref.iterdir():
 if not file.is_file()or file.suffix in compiled:continue
 if file.name.startswith(('acceptance','correctness','count-','host-tests','native-adapter-','legacy-diagnostics')):continue
 if file.suffix in ['.py','.json','.sml','.reference','.observations','.report','.patch','.log','.stdout','.stderr','.txt','.state']:
  data=file.read_bytes()
  if 0 not in data and not data.startswith(bytes([127])+b'ELF'):
   target=file.stem+'.observations'if file.suffix=='.state'else file.name
   shutil.copy(file,observer/target)
for name in ['source','observer-source','small-observer-source']:copy(ref/name,observer/name)
for name in ['inventory-tests.log','inventory-check.log']:shutil.copy(ref/name,out/name)
shutil.copy(ref/'public-target-v3.log',out/'public-target.log')
with(out/'source-identities.tsv').open('w')as f:
 for file in sorted(observer.rglob('*')):
  if file.is_file():f.write(hashlib.sha256(file.read_bytes()).hexdigest()+'\t'+str(file.relative_to(out))+'\n')
 rows=[r for r in csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t')if r['benchmark']in names]
 for file in sorted({x for r in rows for x in r['sources'].split(',')}):f.write(hashlib.sha256((suite/file).read_bytes()).hexdigest()+'\t'+file+'\n')
(out/'.gitattributes').write_text('attempts-raw/** -whitespace\ncounts/** -whitespace\nnative-adapter-diagnostics/** -whitespace\nsemantics/** -whitespace\nsemantics-*.log -whitespace\nreference-observers/** -text -whitespace\nlegacy-diagnostics/** -text -whitespace\ndevelopment/** -text -whitespace\ntotal-diagnostics/** -text -whitespace\n')
print(required,'/112primary; see final 108-assertion semantic summary;16normalcounts;',fresh,'serialsmokefresh;legacydefault/nurserydiagnosticsseparate')
subprocess.run(['python3',str(root/'tests/out/benchmarks/compact-simple-inputs-v2.py')],check=True)
