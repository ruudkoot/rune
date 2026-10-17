from pathlib import Path
import subprocess,json,resource
p=Path(__file__).resolve().parent
cases={
'empty-query':'?-\nbye\n',
'parse-empty-name':'.\n??\nbye\n',
'backspaces':'?- equals(X,X)\nzz\b\bbye\n',
'no-answer':'?- equals(a,b)\nbye\n',
'aliasing':'?- equals(X,Y)\n;\nbye\n',
'append-order':'?- append(X,Y,cons(a,cons(b,nil)))\n;;;\nbye\n',
'cut-source':'p(a).\np(b).\nq(X):==p(X),!.\n?- q(X)\n;\nbye\n',
'unknown-and-blank':'this is invalid\n\nbye\n',
'arity':'p(a).\np(a,b).\n?- p(a,X)\n;\nbye\n',
'numbered-variables':'p(X,Y).\n?- p(A,B)\n;\nbye\n',
'quit-tail':'bye\nnot used at all\n',
}
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for name,contents in cases.items():
 (p/(name+'.input')).write_text(contents)
 for engine in ['stack','pure']:
  d=p/engine;out=p/(name+'-'+engine+'.text')
  r=subprocess.run([str(d/'observer'),str(p/(name+'.input')),str(out),'+RTS','-M256m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
  (p/(name+'-'+engine+'.observe')).write_bytes(r.stdout);print(name,engine,r.stdout.decode().strip(),flush=True)
(p/'extra-cases.json').write_text(json.dumps(cases,indent=2)+'\n')
