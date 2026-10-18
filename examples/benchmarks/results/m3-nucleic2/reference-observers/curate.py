from pathlib import Path
import csv,hashlib,json,re,shutil,os
root=Path.cwd();p=Path(__file__).resolve().parent
suite=root/'examples/benchmarks';dest=suite/'results/m3-nucleic2'
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
def normalize(name):return name.translate(str.maketrans(':@/','---'))
def outcome(log,cfg,stdout,stderr,compilelog):
 if re.search(r'^PROGRAM PASS '+re.escape(cfg)+r'$',log,re.M):return'pass'
 matches=[line for line in log.splitlines()if line.startswith('PROGRAM FAIL '+cfg+' ')]
 if not matches:return'missing-configuration'if 'configuration unavailable'in log else'incomplete'
 line=matches[-1]
 if 'load 1'in line:
  if 'compile timed out'in compilelog:return'compile-timeout'
  if 'timed out'in compilelog and cfg.startswith('rune'):return'runtime-timeout'
  if 'timed out'in compilelog:return'timeout-phase-unclassified'
  if re.search(r'out of memory|memory limit|virtual memory exhausted|unable to map|unable to allocate',compilelog,re.I):return'memory-limit-phase-unclassified'if cfg.startswith('native:smlnj')else'compile-memory-limit'
  return'compile-failure-unclassified'if not compilelog.strip()else'compile-error'
 if 'exit 124'in line:return'timeout'
 if re.search(r'incorrect result|expected ',stdout):return'incorrect-result'
 if re.search(r'out of memory|memory limit|allocation limit',stdout+stderr,re.I):return'memory-limit'
 return'runtime-failure'

names=['nucleic2-lazy','nucleic2-strict','nucleic2-shared-lazy','nucleic2-shared-strict']
assert json.loads((p/'acceptance-final-exit.json').read_text())['exit']==0
exits=json.loads((p/'primary-exits.json').read_text());assert len(exits)==4
assert len(json.loads((p/'count-exits.json').read_text()))==4
dest.mkdir(exist_ok=True)
(dest/'.gitattributes').write_text('# Exact raw source, fixtures and execution evidence.\n** -whitespace\n')
for f in sorted(p.iterdir()):
 if f.is_file():copy(f,dest/'reference-observers'/f.name)
for directory in ['on-demand','shared','str-mode','original-main','base-source','local-public','before-smoke-limit-override','legacy-heap-128k','legacy-heap-1m','legacy-heap-128m','trace-matrix']:
 tree(p/directory,dest/'reference-observers'/directory)
raw=[];canonical={}
def archive_profile(logfile,level,profile,replacement=False):
 text=logfile.read_text();run=Path(re.search(r'^BENCH OUTPUT (.+)$',text,re.M)[1])
 for job in sorted(run.iterdir()):
  if not job.is_dir()or not(job/'result.log').exists():continue
  name=job.name;assert name in names
  log=(job/'result.log').read_text()
  statuses={}
  for line in log.splitlines():
   if line.startswith(('PROGRAM PASS ','PROGRAM FAIL ','PROGRAM SKIP ')):statuses[normalize(line.split()[2])]=line.split()[2]
  for cfgdir in sorted((job/'matrix').iterdir()):
   if not cfgdir.is_dir()or not(cfgdir/'program').exists():continue
   cfg=statuses.get(cfgdir.name,cfgdir.name);program=cfgdir/'program'
   epoch='smoke-override'if replacement else'initial-profile-gates'
   saved=dest/'correctness'/epoch/level/profile/name/cfgdir.name
   tree(program,saved)
   for n in ['input','sources.txt','data.txt','result.log']:copy(job/n,saved/('matrix-'+n if n=='result.log'else n))
   def read(n):return(program/n).read_text(errors='replace')if(program/n).exists()else''
   state=outcome(log,cfg,read('stdout'),read('stderr'),read('log'))
   row=[name,profile,level,'host-default'if cfgdir.name.startswith('native-')else level,cfg,state,str(saved.relative_to(suite))]
   raw.append(row);canonical[name,profile,level,cfg]=row
 copy(logfile,dest/logfile.name)
for record in exits:archive_profile(Path(record['log']),record['level'],record['profile'])
assert len(raw)==112,('initial primary outcomes',len(raw))
archive_profile(p/'smoke-override-O0.log','O0','smoke',True)
assert len(raw)==116 and len(canonical)==112
header=['benchmark','profile','requested_level','effective_options','configuration','status','artifact_directory']
table(dest/'correctness-attempts.tsv',header,raw)
table(dest/'correctness.tsv',header,[canonical[key]for key in sorted(canonical)])
semLog=(p/'semantic-matrix.log').read_text()
match=re.search(r'\((/[^)]+)\)',semLog);assert match
semantic=Path(match[1]);semrows=[]
for level in ['O0','O2']:
 log=(semantic/(level+'.log')).read_text();copy(semantic/(level+'.log'),dest/('semantic-'+level+'.log'))
 for cfgdir in sorted((semantic/level).iterdir()):
  if not cfgdir.is_dir()or not(cfgdir/'program').exists():continue
  program=cfgdir/'program';out=(program/'stdout').read_text(errors='replace')
  passes=len(re.findall(r'^PASS ',out,re.M));failures=len(re.findall(r'^FAIL ',out,re.M))
  summaries=re.findall(r'^SUMMARY (\d+) checks, (\d+) failed',out,re.M)
  complete=bool(summaries)
  state='pass'if summaries and summaries[-1]==('5081','0')else'runtime-failure'if passes+failures else'compile-failure-unclassified'
  saved=dest/'semantics'/level/cfgdir.name;tree(program,saved)
  semrows.append([level,cfgdir.name,state,passes,failures,str(complete).lower(),5081 if complete else passes+failures,str(saved.relative_to(suite))])
assert len(semrows)==14,len(semrows)
table(dest/'semantics.tsv',['requested_level','configuration','status','passed','failed','complete','recorded_checks','artifact_directory'],semrows)
for name in names:
 guard=json.loads((p/('count-'+name+'.json')).read_text());assert guard['exit']==0 and guard['guard_reason']is None
 text=(p/('count-'+name+'-guard.log')).read_text();assert'COUNT comparisons agree'in text
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',text,re.M)[1]);tree(run,dest/'counts'/name)
text=(p/'serial-native-final.log').read_text();run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',text,re.M)[1])
samples=list(csv.DictReader((run/'samples.tsv').open(),delimiter='\t'))
assert sum(r['phase']=='fresh'and r['status']=='pass'for r in samples)==8
assert sum(r['phase']=='correctness'and r['status']!='pass'for r in samples)==4
tree(run,dest/'fresh-adapter-diagnostics')
table(dest/'excluded-payloads.tsv',['original_path','bytes','sha256'],sorted(set(skipped)))
summary=dict(primary_combinations=len(canonical),primary_pass=sum(row[5]=='pass'for row in canonical.values()),primary_failures=[row for row in canonical.values()if row[5]!='pass'],all_attempts=len(raw),semantic_groups=len(semrows),semantic_pass=sum(row[3]for row in semrows),semantic_fail=sum(row[4]for row in semrows),semantic_complete=sum(row[5]=='true'for row in semrows),normal_count_samples=16,fresh_adapter_samples=8,acceptance=json.loads((p/'acceptance-final-exit.json').read_text()))
(dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
