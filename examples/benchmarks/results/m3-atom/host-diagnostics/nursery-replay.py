from pathlib import Path
import subprocess,resource,json,re,hashlib
p=Path(__file__).resolve().parent;root=Path.cwd();run=Path(re.search('VALIDATION OUTPUT (.+)',(p/'correctness-final.log').read_text())[1]);semantic=Path(re.findall(r'\((/[^\n]+)\)',(p/'semantics-final.log').read_text())[-1])
cases=[('semantics',semantic/'O0/native-smlnj-legacy-110.99.9/program',None),('trace',p/'trace-probe/native-smlnj-legacy-110.99.9/program',None)]
for name in ['atom-lazy','atom-strict']:
 for profile in ['smoke','normal']:
  job=run/name/profile/'hosts';cases.append((name+'-'+profile,job/'matrix/native-smlnj-legacy-110.99.9/program',job/'input'))
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
results=[]
for label,work,stdin in cases:
 for mode in ['default','nursery64m']:
  command=['/home/ruud/.local/rune-hosts/smlnj-legacy/bin/sml']+(['@SMLalloc=64m']if mode!='default'else[])+['driver.sml'];log=p/('nursery-'+label+'-'+mode+'.log')
  with log.open('w')as output:
   if stdin:
    with stdin.open()as source:r=subprocess.run(command,cwd=work,stdin=source,stdout=output,stderr=subprocess.STDOUT,timeout=180,preexec_fn=cap)
   else:r=subprocess.run(command,cwd=work,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,timeout=180,preexec_fn=cap)
  raw=log.read_text();row=dict(case=label,mode=mode,exit=r.returncode,summary=re.findall(r'^SUMMARY (\d+) checks, (\d+) failed$',raw,re.M),details=[line for line in raw.splitlines()if line.startswith(('FAIL ','DETAIL '))]);results.append(row);print(row,flush=True)
(p/'nursery-replays.json').write_text(json.dumps(results,indent=2)+'\n')
(p/'diagnostic-source-identities.tsv').write_text(''.join(hashlib.sha256((root/file).read_bytes()).hexdigest()+'\t'+file+'\n'for file in ['examples/benchmarks/shared/finite-binary32.sml','examples/benchmarks/shared/nofib-atom.sml','examples/benchmarks/shared/nofib-atom-driver.sml','tests/benchmarks/atom-tests.sml']))
