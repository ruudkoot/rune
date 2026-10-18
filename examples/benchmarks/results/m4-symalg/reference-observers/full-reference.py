from pathlib import Path
import shutil,subprocess,resource,json,hashlib
p=Path(__file__).resolve().parent
d=p/'full-observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('original','observer','*.hi','*.o','Observer*','build.log'),dirs_exist_ok=True)
f=d/'Print.hs';s=f.read_text();old='mybasicNumber2str x p = show (hash (basicNumber2str x p))'
assert s.count(old)==1;f.write_text(s.replace(old,'mybasicNumber2str x p = basicNumber2str x p'))
patch=subprocess.run(['diff','-u',str(p/'source/Print.hs'),str(f)],capture_output=True)
(p/'full-output-observer.patch').write_bytes(patch.stdout)
with(p/'full-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','full-observer','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
smoke='$prec = 20\n'+''.join('sqrt('+str(i)+')\n'for i in range(2,11))+'exit\n'
(p/'smoke.stdin').write_text(smoke)
cases=[('smoke',p/'smoke.stdin'),('source-fast',p/'source/symalg.faststdin'),('normal',p/'source/symalg.stdin'),('source-slow',p/'source/symalg.slowstdin')]
records=[]
for name,inp in cases:
 result=subprocess.run([str(d/'full-observer'),'+RTS','-M512m','-RTS'],input=inp.read_bytes(),capture_output=True,timeout=600,preexec_fn=cap,check=True)
 (p/(name+'.full-output')).write_bytes(result.stdout);(p/(name+'.full-stderr')).write_bytes(result.stderr)
 # The scripts contain a precision assignment followed by sqrt(integer) calls.
 # Retain full precision assignment values (printed twice), then every exact
 # decimal result. Reconstruct the complete observer transcript as a check.
 lines=inp.read_text().splitlines();prec=lines[0].split('=')[1].strip()
 prefix='-> Eval\t'+prec+'\nSet\t$prec to '+prec+'\n'
 text=result.stdout.decode();assert text.startswith(prefix)
 tail=text[len(prefix):];assert tail.endswith('-> ')
 values=[prec,prec]
 for line in tail[:-3].splitlines():
  assert line.startswith('-> ');values.append(line[3:])
 assert len(values)==len(lines)
 (p/(name+'.numbers.reference')).write_text('\n'.join(values)+'\n')
 if name=='smoke':
  raw=subprocess.run([str(p/'source/original')],input=inp.read_bytes(),capture_output=True,timeout=60,check=True)
  (p/'smoke.stdout').write_bytes(raw.stdout)
 records.append(dict(profile=name,precision=int(prec),values=len(values),bytes=len(result.stdout),sha256=hashlib.sha256(result.stdout).hexdigest()))
 print(records[-1],flush=True)
(p/'full-reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
