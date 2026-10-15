from pathlib import Path
import subprocess,json
p=Path(__file__).parent;up=Path('/home/ruud/reference/ghc/nofib/real/grep')
subprocess.run(['ghc','-O2','-i'+str(up),'-outputdir',str(p/'build'),'-o',str(p/'original'),str(up/'Main.lhs')],check=True,stdout=(p/'build.log').open('w'),stderr=subprocess.STDOUT)
with(p/'reference.log').open('w')as log:
 for profile,n,file in [('smoke',1,'grep.faststdin'),('normal',150,'grep.stdin'),('large',250,'grep.slowstdin')]:
  data=(up/file).read_bytes();result=subprocess.run([str(p/'original'),str(n),'.*:..*'],input=data,capture_output=True,check=True,timeout=120)
  (p/(profile+'.stdout')).write_bytes(result.stdout)
  # Independent fixed-pattern semantics: at least one character after a colon.
  selected=[line for line in data.decode('utf-8').split('\n') if any(c==':' and i+1<len(line)for i,c in enumerate(line))]
  text=''.join(line+'\n'for line in selected);h=0
  for c in text:h=(ord(c)+h*31)&((1<<64)-1)
  if h>=1<<63:h-=1<<64
  assert result.stdout==(str(h)+'\n').encode()*n
  (p/(profile+'-selected.json')).write_text(json.dumps(selected,ensure_ascii=False)+'\n')
  print('PASS original and independent Unicode line filter',profile,n,len(selected),h,file=log,flush=True)
