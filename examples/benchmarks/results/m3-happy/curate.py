from pathlib import Path
import csv,hashlib,json,re,shutil,os
root=Path.cwd();p=Path(__file__).resolve().parent
suite=root/'examples/benchmarks';dest=suite/'results/m3-happy'
compiled={'.rbc','.o','.hi','.exe','.heap','.state','.cmx','.cmi','.cmo','.a','.cmxa','.cma','.dyn_o','.dyn_hi'}
skipped=[]
def copy(source,target):
 if not source.is_file():return
 if source.suffix in compiled or any(v in ['MLB','.cm','.git']for v in source.parts):
  skipped.append((str(source.relative_to(root))if source.is_relative_to(root)else str(source),source.stat().st_size,'-'));return
 binary=False
 digest=hashlib.sha256();size=0;first=True
 with source.open('rb')as f:
  while True:
   block=f.read(1048576)
   if not block:break
   if first:
    binary=binary or block.startswith((bytes([127])+b'ELF',b'MZ',b'!<arch>\\n',b'\\x1f\\x8b'))
    first=False
   binary=binary or 0 in block;size+=len(block);digest.update(block)
 if binary:
  skipped.append((str(source.relative_to(root))if source.is_relative_to(root)else str(source),size,digest.hexdigest()));return
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
def tree(source,target):
 if not source.exists():return
 for current,dirs,files in os.walk(source):
  dirs[:]=sorted(d for d in dirs if d not in ['MLB','.cm','.git'])
  for name in sorted(files):
   f=Path(current)/name
   copy(f,target/f.relative_to(source))
def table(path,header,rows):
 path.parent.mkdir(parents=True,exist_ok=True)
 with path.open('w',newline='')as f:
  w=csv.writer(f,delimiter='\t',lineterminator='\n');w.writerow(header);w.writerows(rows)
assert json.loads((p/'acceptance-final-exit.json').read_text())['exit']==0
exits=json.loads((p/'primary-exits.json').read_text());assert len(exits)==4
assert all((p/r['log']).exists()if not Path(r['log']).is_absolute()else Path(r['log']).exists()for r in exits)
assert 'bench-happy:' in(p/'semantic-matrix.log').read_text()
assert len(json.loads((p/'count-exits.json').read_text()))==2
dest.mkdir(exist_ok=True)
copy(suite/'results/m4-rsa/.gitattributes',dest/'.gitattributes')
with(dest/'.gitattributes').open('a')as f:
 f.write('\n# Exact archived runtime inputs, source snapshots and output evidence.\ncorrectness/** -whitespace\nsemantics/** -whitespace\ncounts/** -whitespace\nfresh-adapter-diagnostics/** -whitespace\n')
# Portable adaptation pieces and independent observers, with bounded selection.
for f in sorted(p.iterdir()):
 if f.is_file():copy(f,dest/'reference-observers'/f.name)
selected=['actions-data','attribute-data','code-data','codegen-data','first-data','grammar-data','lexer-data','literal-data','lookahead-data','lr0-data','parser-data','set-data','end-to-end-data','base-source','release','source','before-nj32-guard','before-radix-overflow-fix','actions-observer-source','codegen-observer-source','lookahead-observer-source','lr0-observer-source','grammar-observer-source','first-observer-source']
for name in selected:tree(p/name,dest/'reference-observers'/name)
# All final configuration outcomes, including failed compilers, remain rows.
rows=[]
def normalize(name):return name.translate(str.maketrans(':@/','---'))
def outcome(log,cfg,stdout,stderr,compilelog):
 if re.search(r'^PROGRAM PASS '+re.escape(cfg)+r'$',log,re.M):return'pass'
 matches=[line for line in log.splitlines()if line.startswith('PROGRAM FAIL '+cfg+' ')]
 if not matches:return'missing-configuration'if 'configuration unavailable'in log else'incomplete'
 line=matches[-1]
 if 'load 1'in line:
  if 'timed out'in compilelog:return'compile-timeout'
  if re.search(r'out of memory|memory limit|virtual memory exhausted',compilelog,re.I):return'compile-memory-limit'
  return'compile-failure-unclassified'if not compilelog.strip()else'compile-error'
 if 'exit 124'in line:return'timeout'
 if re.search(r'incorrect result|expected |SUMMARY \d+ checks, [1-9]\d* failed',stdout):return'incorrect-result'
 if re.search(r'out of memory|memory limit|allocation limit',stdout+stderr,re.I):return'memory-limit'
 return'runtime-failure'
for record in exits:
 logfile=Path(record['log']);text=logfile.read_text()
 run=Path(re.search(r'^BENCH OUTPUT (.+)$',text,re.M)[1])
 for name in ['happy-lazy','happy-strict']:
  job=run/name
  log=(job/'result.log').read_text()
  statuses={}
  for line in log.splitlines():
   if line.startswith(('PROGRAM PASS ','PROGRAM FAIL ','PROGRAM SKIP ')):statuses[normalize(line.split()[2])]=line.split()[2]
  for cfgdir in sorted((job/'matrix').iterdir()):
   if not cfgdir.is_dir()or not(cfgdir/'program').exists():continue
   cfg=statuses.get(cfgdir.name,cfgdir.name)
   program=cfgdir/'program';saved=dest/'correctness'/record['level']/record['profile']/name/cfgdir.name
   tree(program,saved)
   for n in ['input','sources.txt','data.txt','result.log']:copy(job/n,saved/('matrix-'+n if n=='result.log'else n))
   def read(n):return(program/n).read_text(errors='replace')if(program/n).exists()else''
   state=outcome(log,cfg,read('stdout'),read('stderr'),read('log'))
   rows.append([name,record['profile'],record['level'],'host-default'if cfgdir.name.startswith('native-')else record['level'],cfg,state,str(saved.relative_to(suite))])
 copy(logfile,dest/logfile.name)
assert len(rows)==80,('raw final profile outcomes',len(rows))
table(dest/'correctness.tsv',['benchmark','profile','requested_level','effective_options','configuration','status','artifact_directory'],rows)
semantic=Path(re.search(r'\((/[^)]+)\)',(p/'semantic-matrix.log').read_text())[1])
semrows=[]
for level in ['O0','O2']:
 log=(semantic/(level+'.log')).read_text()
 copy(semantic/(level+'.log'),dest/('semantic-'+level+'.log'))
 for cfgdir in sorted((semantic/level).iterdir()):
  if not cfgdir.is_dir()or not(cfgdir/'program').exists():continue
  out=(cfgdir/'program/stdout').read_text(errors='replace')
  summaries=re.findall(r'^SUMMARY (\d+) checks, (\d+) failed',out,re.M)
  cfg=cfgdir.name
  saved=dest/'semantics'/level/cfg
  tree(cfgdir/'program',saved)
  assert summaries and summaries[-1]==('2514','0'),(level,cfg,summaries)
  semrows.append([level,cfg,2514,0,str(saved.relative_to(suite))])
assert len(semrows)==20
table(dest/'semantics.tsv',['requested_level','configuration','checks','failed','artifact_directory'],semrows)
# Measurement manifests, raw samples, readable builds and exact identities.
for mode in ['happy-lazy','happy-strict']:
 guard=json.loads((p/('count-'+mode+'.json')).read_text());assert guard['exit']==0 and guard['guard_reason']is None
 log=(p/('count-'+mode+'-guard.log')).read_text();assert'COUNT comparisons agree'in log
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',log,re.M)[1])
 tree(run,dest/'counts'/mode)
# Fresh adapter diagnostics are required to be from the final source.
log=(p/'serial-native-final.log').read_text()
run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',log,re.M)[1])
samples=list(csv.DictReader((run/'samples.tsv').open(),delimiter='\t'))
assert sum(r['phase']=='fresh'and r['status']=='pass'for r in samples)==6
assert all(r['status']=='pass'for r in samples)
tree(run,dest/'fresh-adapter-diagnostics')
table(dest/'excluded-payloads.tsv',['original_path','bytes','sha256'],sorted(set(skipped)))
summary=dict(primary_profiles=len(rows),primary_pass=sum(r[5]=='pass'for r in rows),primary_failures=[r for r in rows if r[5]!='pass'],semantic_configurations=len(semrows),semantic_checks=sum(r[2]for r in semrows),semantic_failures=0,normal_count_samples=8,fresh_adapter_samples=6,acceptance=json.loads((p/'acceptance-final-exit.json').read_text()))
(dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
