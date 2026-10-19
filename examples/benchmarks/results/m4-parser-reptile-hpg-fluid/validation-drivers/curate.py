from pathlib import Path
import csv,hashlib,json,re,shutil,os
root=Path.cwd();p=Path(__file__).resolve().parent
suite=root/'examples/benchmarks';dest=suite/'results/m4-parser-reptile-hpg-fluid'
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


names=[family+'-'+policy for family in ['parser','reptile','hpg','fluid']for policy in ['lazy','strict']]
assert json.loads((p/'acceptance-exit.json').read_text())['exit']==0
dest.mkdir(exist_ok=True)
(dest/'.gitattributes').write_text('# Exact source, fixtures and execution evidence.\n** -whitespace\n')
for f in sorted(p.iterdir()):
 if f.is_file():copy(f,dest/'validation-drivers'/f.name)
for family in ['parser','reptile','hpg','fluid']:
 tree(root/('tests/out/benchmarks/nofib-'+family+'-originals'),dest/'reference-observers'/family)
for directory in ['before-parser-test-annotation','before-fluid-shared-test-kernel','legacy-types']:
 tree(p/directory,dest/'validation-drivers'/directory)
primary=[]
for item in json.loads((p/'primary-outcomes.json').read_text()):
 original=Path(item['path']);job=original.parent;cfg=item['status'].split()[2]
 saved=dest/'correctness'/item['level']/item['profile']/job.name/normalize(cfg)
 program=job/'matrix'/normalize(cfg)/'program'
 assert program.exists(),str(program)
 tree(program,saved)
 for n in ['input','sources.txt','data.txt','result.log']:copy(job/n,saved/('matrix-'+n if n=='result.log'else n))
 def read(n):return(program/n).read_text(errors='replace')if(program/n).exists()else''
 state=outcome(original.read_text(),cfg,read('stdout'),read('stderr'),read('log'))
 primary.append([job.name,item['profile'],item['level'],'host-default'if cfg.startswith('native:')else item['level'],cfg,state,str(saved.relative_to(suite))])
assert len(primary)==224 and sum(row[5]=='pass'for row in primary)==209
table(dest/'correctness.tsv',['benchmark','profile','requested_level','effective_options','configuration','status','artifact_directory'],primary)
semraw=[];canonical={}
def semantics(family,epoch,logfile):
 content=logfile.read_text();matches=re.findall(r'\((/[^)\n]+)\)',content);assert matches,str(logfile)
 source=Path(matches[-1]);assert source.exists()
 copy(logfile,dest/'semantics'/epoch/family/'runner.log')
 for level in ['O0','O2']:
  combined=source/(level+'.log')
  if not combined.exists():continue
  copy(combined,dest/'semantics'/epoch/family/(level+'.log'))
  for cfgdir in sorted((source/level).iterdir()):
   if not cfgdir.is_dir()or not(cfgdir/'program').exists():continue
   program=cfgdir/'program';out=(program/'stdout').read_text(errors='replace')if(program/'stdout').exists()else''
   passed=len(re.findall(r'^PASS ',out,re.M));failed=len(re.findall(r'^FAIL ',out,re.M))
   sums=re.findall(r'^SUMMARY (\d+) checks, (\d+) failed',out,re.M)
   complete=bool(sums)
   cfgs=[line.split()[2]for line in combined.read_text().splitlines()if line.startswith(('PROGRAM PASS ','PROGRAM FAIL ','PROGRAM SKIP '))and normalize(line.split()[2])==cfgdir.name]
   cfg=cfgs[-1]if cfgs else cfgdir.name
   saved=dest/'semantics'/epoch/family/level/cfgdir.name;tree(program,saved)
   row=[family,epoch,level,cfg,'pass'if complete and not failed else'failed'if failed else'incomplete',
        passed,failed,'true'if complete else'false',int(sums[-1][0])if sums else'',str(saved.relative_to(suite))]
   semraw.append(row);canonical[family,level,cfg]=row
for family in ['parser','reptile','hpg','fluid']:semantics(family,'initial',p/('semantics-'+family+'.log'))
semantics('parser','parser-test-type-annotation',p/'parser-semantic-smlnj-retry.log')
semantics('fluid','fluid-shared-test-kernel',p/'fluid-semantic-shared-kernel.log')
header=['family','epoch','requested_level','configuration','status','passed','failed','complete','recorded_checks','artifact_directory']
table(dest/'semantic-attempts.tsv',header,semraw)
table(dest/'semantics.tsv',header,[canonical[k]for k in sorted(canonical)])
assert len(canonical)==56
for name in names:
 guard=json.loads((p/('count-'+name+'.json')).read_text());assert guard['exit']==0 and guard['guard_reason']is None
 log=(p/('count-'+name+'-guard.log')).read_text();assert'COUNT comparisons agree'in log
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',log,re.M)[1]);tree(run,dest/'counts'/name)
for family in ['parser','reptile','hpg','fluid']:
 logfile=p/('serial-native-'+family+'.log')
 run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',logfile.read_text(),re.M)[1])
 tree(run,dest/'fresh-adapter-diagnostics'/'initial'/family)
 if family!='parser':
  logfile=p/('serial-native-fixed-'+family+'.log')
  run=Path(re.search(r'^BENCH MEASUREMENT (.+)$',logfile.read_text(),re.M)[1])
  tree(run,dest/'fresh-adapter-diagnostics'/'portable-type-annotations'/family)
summary=dict(programs=503,profiles=1461,primary_combinations=224,primary_pass=209,rune_pass=128,
 semantic_groups=len(canonical),semantic_raw_groups=len(semraw),semantic_complete=sum(row[7]=='true'for row in canonical.values()),
 semantic_pass=sum(row[5]for row in canonical.values()),semantic_fail=sum(row[6]for row in canonical.values()),
 normal_count_samples=32,fresh_adapter_samples=20,fresh_preflight_rejections=4,
 acceptance=json.loads((p/'acceptance-exit.json').read_text()))
(dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
table(dest/'excluded-payloads.tsv',['original_path','bytes','sha256'],sorted(set(skipped)))
print(json.dumps(summary,indent=2))
