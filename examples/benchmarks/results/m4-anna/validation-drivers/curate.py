from pathlib import Path
import csv,hashlib,json,re,shutil,os
root=Path.cwd();p=Path(__file__).resolve().parent
suite=root/'examples/benchmarks';dest=suite/'results/m4-anna'
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


assert json.loads((p/'acceptance-exit.json').read_text())['exit']==0
dest.mkdir(exist_ok=True)
(dest/'.gitattributes').write_text('# Exact source and execution evidence.\n** -whitespace\n')
for f in p.iterdir():
 if f.is_file():copy(f,dest/'validation-drivers'/f.name)
for name in ['before-closed-size-pair','smlnj32-type-probe','smlnj32-literal-probe']:
 tree(p/name,dest/'validation-drivers'/name)
tree(root/'tests/out/benchmarks/nofib-anna-originals',dest/'reference-observers')
rows=[]
for item in json.loads((p/'primary-outcomes.json').read_text()):
 logfile=Path(item['path']);job=logfile.parent;cfg=item['outcome'].split()[2]
 program=job/'matrix'/normalize(cfg)/'program';assert program.exists(),str(program)
 saved=dest/'correctness'/item['level']/item['profile']/job.name/normalize(cfg);tree(program,saved)
 for name in ['input','sources.txt','data.txt','result.log']:copy(job/name,saved/('matrix-'+name if name=='result.log'else name))
 def read(name):return(program/name).read_text(errors='replace')if(program/name).exists()else''
 state=outcome(logfile.read_text(),cfg,read('stdout'),read('stderr'),read('log'))
 rows.append([job.name,item['profile'],item['level'],'host-default'if cfg.startswith('native:')else item['level'],cfg,state,str(saved.relative_to(suite))])
assert len(rows)==56 and sum(row[5]=='pass'for row in rows)==45
table(dest/'correctness.tsv',['benchmark','profile','requested_level','effective_options','configuration','status','artifact_directory'],rows)
content=(p/'semantic-matrix.log').read_text();semantic=Path(re.findall(r'\((/[^)\n]+)\)',content)[-1]);semrows=[]
for level in ['O0','O2']:
 copy(semantic/(level+'.log'),dest/'semantics'/(level+'.log'))
 for cfgdir in sorted((semantic/level).iterdir()):
  if not cfgdir.is_dir()or not(cfgdir/'program').exists():continue
  program=cfgdir/'program';out=(program/'stdout').read_text(errors='replace')if(program/'stdout').exists()else''
  passed=len(re.findall(r'^PASS ',out,re.M));failed=len(re.findall(r'^FAIL ',out,re.M));summaries=re.findall(r'^SUMMARY (\d+) checks, (\d+) failed',out,re.M)
  saved=dest/'semantics'/level/cfgdir.name;tree(program,saved)
  semrows.append([level,cfgdir.name,'pass'if summaries and not failed else'failed'if failed else'incomplete',passed,failed,
       'true'if summaries else'false',int(summaries[-1][0])if summaries else'',str(saved.relative_to(suite))])
table(dest/'semantics.tsv',['requested_level','configuration','status','passed','failed','complete','recorded_checks','artifact_directory'],semrows)
assert len(semrows)==14 and sum(row[3]for row in semrows)==23560 and sum(row[4]for row in semrows)==0
for name in ['anna-lazy','anna-strict']:
 guard=json.loads((p/('count-'+name+'.json')).read_text());assert guard['exit']==0 and guard['guard_reason']is None
 content=(p/('count-'+name+'-guard.log')).read_text();assert'COUNT comparisons agree'in content
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',content,re.M)[1]);tree(run,dest/'counts'/name)
for epoch,logfile in [('initial',p/'serial-native.log'),('closed-size-pair',p/'serial-native-fixed.log'),('classification-fixed',p/'serial-native-classification.log')]:
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',logfile.read_text(),re.M)[1]);tree(run,dest/'fresh-adapter-diagnostics'/epoch)
fixture=Path(re.findall(r'\((/[^)\n]+)\)',(p/'measurement-status.log').read_text())[-1])
tree(fixture,dest/'measurement-status-regressions')
for name in ['error','timeout','no_image']:
 logfile=fixture/(name+'.log');run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',logfile.read_text(),re.M)[1])
 tree(run,dest/'measurement-status-regressions'/name)
summary=dict(programs=505,profiles=1467,profile_combinations=56,profile_pass=45,rune_pass=32,
 semantic_groups=14,semantic_complete=12,semantic_pass=23560,semantic_fail=0,
 normal_count_samples=8,fresh_adapter_samples=4,
 acceptance=json.loads((p/'acceptance-exit.json').read_text()))
(dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
table(dest/'excluded-payloads.tsv',['original_path','bytes','sha256'],sorted(set(skipped)))
print(json.dumps(summary,indent=2))
