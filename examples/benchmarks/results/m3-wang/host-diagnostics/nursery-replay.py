from pathlib import Path
import subprocess,resource,json,re,hashlib
p=Path(__file__).resolve().parent;hosts=Path('/home/ruud/.local/rune-hosts');rows=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for host,version in [('smlnj-legacy','110.99.9'),('smlnj32','110.99.9'),('smlnj-dev','2026.2')]:
 work=p/'diagnostic-O2'/('native-'+host+'-'+version)/'program'
 for mode in ['default','nursery64m']:
  log=p/('nursery-'+host+'-'+mode+'.log');cmd=[str(hosts/host/'bin/sml')]+(['@SMLalloc=64m']if mode!='default'else[])+['driver.sml']
  with log.open('w')as f:r=subprocess.run(cmd,cwd=work,stdin=subprocess.DEVNULL,stdout=f,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=180)
  raw=log.read_text();summary=re.findall(r'^SUMMARY (\d+) checks, (\d+) failed$',raw,re.M);row=dict(host=host,version=version,mode=mode,exit=r.returncode,summary=summary,failures=[line for line in raw.splitlines()if line.startswith(('FAIL ','DETAIL '))],fatal=[line for line in raw.splitlines()if 'Fatal error'in line]);rows.append(row);print(row,flush=True)
(p/'nursery-replays.json').write_text(json.dumps(rows,indent=2)+'\n')
(p/'diagnostic-source-identities.tsv').write_text(''.join(hashlib.sha256((p/file).read_bytes()).hexdigest()+'\t'+file+'\n'for file in ['kernel.sml','driver.sml','tests.sml']))
