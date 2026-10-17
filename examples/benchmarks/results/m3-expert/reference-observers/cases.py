from pathlib import Path
import subprocess,shutil,resource,json
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
f=d/'Main.hs';text=f.read_text().replace('module Main where','module Expert where');(d/'Expert.hs').write_text(text)
(d/'Observer.hs').write_text('''module Main where
import Expert
main = readFile "runtime_files/animals" >>= \\animals -> getContents >>= putStr . process animals
''')
with(d/'build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
cases={'source':(p/'source/expert.stdin').read_text(),'lower-no':('no\n'*20),'uppercase-no':('No\n'*20),'all-yes':('yes\n'*20),'stop-first':'yes\nyes\nno\n','mixed':'yes\nno\nyes\nno\nno\nyes\nno\nyes\nno\n'}
out=p/'cases';out.mkdir(exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
records=[]
for name,input in cases.items():
 (out/(name+'.input')).write_text(input)
 r=subprocess.run([str(d/'observer'),'+RTS','-M128m','-RTS'],cwd=d,input=input.encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap)
 (out/(name+'.output')).write_bytes(r.stdout);(out/(name+'.stderr')).write_bytes(r.stderr)
 records.append(dict(name=name,exit_code=r.returncode,bytes=len(r.stdout)));print(records[-1],flush=True)
(p/'case-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
