from pathlib import Path
import bisect,hashlib,json,resource,subprocess
root=Path.cwd();p=Path(__file__).resolve().parent;up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/benchmarksgame'
modulus=139968;iub=[('a',.27),('c',.12),('g',.12),('t',.27)]+[(c,.02)for c in 'BDHKMNRSVWY'];homo=[('a',.302954942668),('c',.1979883004921),('g',.1975473066391),('t',.3015094502008)]
seed=42;states=[]
for _ in range(modulus):seed=(seed*3877+29573)%modulus;states.append(seed)
assert seed==42 and len(set(states))==modulus
cycles={};sources={};metadata={'compiler':subprocess.check_output(['ocamlopt','-version'],text=True).strip(),'programs':{},'profiles':[]}
for name in ['fasta3','fasta6']:
 source=(up/(name+'.ml')).read_text();sources[name]=source;(p/(name+'.ml')).write_bytes((up/(name+'.ml')).read_bytes())
 assert source.count('\nlet () =\n')==1
 prefix=source.split('\nlet () =\n')[0]
 main='\nlet () = last := 42; make_random_fasta "IUB" "cycle" iub 139968; last := 42; make_random_fasta "HOMO" "cycle" homosapiens 139968\n'if name=='fasta3'else'\nlet () = ignore(make_random_fasta 42 "IUB" "cycle" iub 139968); ignore(make_random_fasta 42 "HOMO" "cycle" homosapiens 139968)\n'
 (p/(name+'_cycles.ml')).write_text(prefix+main)
 for stem in [name,name+'_cycles']:
  with(p/(stem+'-build.log')).open('w')as log:subprocess.run(['ocamlopt','-O2','-o',stem,stem+'.ml'],cwd=p,check=True,stdout=log,stderr=subprocess.STDOUT)
 observed=subprocess.check_output([str(p/(name+'_cycles'))]);parts=observed.split(b'>HOMO cycle\n');assert len(parts)==2
 tables=[parts[0].split(b'\n',1)[1].replace(b'\n',b''),parts[1].replace(b'\n',b'')]
 for label,distribution,actual in zip(['iub','homo'],[iub,homo],tables):
  thresholds=[];total=0.0
  for _,probability in distribution:total+=probability;thresholds.append(total)
  expected=bytes(ord(distribution[bisect.bisect_right(thresholds,(1.0*float(n)/float(modulus))if name=='fasta3'else float(n)*(1.0/float(modulus)))][0])for n in states)
  assert actual==expected and len(actual)==modulus
  (p/(name+'-'+label+'.cycle')).write_bytes(actual);cycles[name,label]=actual
 print('PASS original and independent complete RNG cycle',name,flush=True)
 metadata['programs'][name]={'source_sha256':hashlib.sha256(source.encode()).hexdigest(),'cycle_hashes':{label:hashlib.sha256(cycles[name,label]).hexdigest()for label in ['iub','homo']}}
assert cycles['fasta3','iub']==cycles['fasta6','iub']and cycles['fasta3','homo']==cycles['fasta6','homo']
# The literal is program data; independent output uses repeated cycles, not the kernels' draw loops.
import re
alu=re.search(r'let alu = "(.*?)"',sources['fasta3'],re.S)[1].replace('\\\n','').encode();assert len(alu)==287
(p/'alu.data').write_bytes(alu)
def body(cycle,count,offset=0):
 position=offset
 for start in range(0,count,60):
  length=min(60,count-start);chunk=bytes(cycle[(position+j)%len(cycle)]for j in range(length));position+=length
  yield chunk+b'\n'
def expected(n):
 yield b'>ONE Homo sapiens alu\n';yield from body(alu,2*n)
 yield b'>TWO IUB ambiguity codes\n';yield from body(cycles['fasta3','iub'],3*n)
 yield b'>THREE Homo sapiens frequency\n';yield from body(cycles['fasta3','homo'],5*n,3*n)
for profile,n,timeout,memory in [('smoke',151,30,1024**3),('normal',50000,600,4*1024**3),('large',25000000,3600,8*1024**3)]:
 digest=hashlib.sha256();length=0
 for chunk in expected(n):digest.update(chunk);length+=len(chunk)
 gold=digest.hexdigest()
 for name in ['fasta3','fasta6']:
  file=p/(name+'-'+profile+'.output')
  def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
  with file.open('wb')as out:subprocess.run([str(p/name),str(n)],stdout=out,stderr=subprocess.PIPE,check=True,timeout=timeout,preexec_fn=limits)
  actual=hashlib.sha256();size=0
  with file.open('rb')as inp:
   while True:
    chunk=inp.read(1024**2)
    if not chunk:break
    actual.update(chunk);size+=len(chunk)
  assert actual.hexdigest()==gold and size==length
  if profile=='large':file.unlink()
  print('PASS original and independent complete FASTA output',name,profile,n,flush=True)
 metadata['profiles'].append({'profile':profile,'n':n,'timeout':timeout,'memory_bytes':memory,'output_bytes':length,'output_sha256':gold})
(p/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
