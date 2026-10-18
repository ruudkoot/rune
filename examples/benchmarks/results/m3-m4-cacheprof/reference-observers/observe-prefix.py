from pathlib import Path
import subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'observer-source'
(d/'Prefix.hs').write_text('module Main where\nimport CacheMain (doFile)\nimport System.Environment\nmain=do {args<-getArgs; input<-getContents; out<-doFile (read(head args)) [] input; putStr(take 1 out)}\n')
with(p/'prefix-build.log').open('w')as log:subprocess.run(['ghc','-O2','-o','prefix','Prefix.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
records=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for level in [0,2]:
 r=subprocess.run([str(d/'prefix'),str(level)],input=b'#keep\nbroken ???\n',capture_output=True,timeout=30,preexec_fn=cap)
 (p/('prefix-level'+str(level)+'.stdout')).write_bytes(r.stdout);(p/('prefix-level'+str(level)+'.stderr')).write_bytes(r.stderr)
 assert (r.returncode==0 and r.stdout==b'#')if level==0 else(r.returncode!=0 and b'Bad input:'in r.stderr)
 records.append(dict(level=level,exit=r.returncode,stdout=r.stdout.decode(),source='first output character followed by invalid later instruction'))
print(records)
(p/'prefix-results.json').write_text(json.dumps(records,indent=2)+'\n')
