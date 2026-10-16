from pathlib import Path
import hashlib,json,resource,subprocess
root=Path.cwd();p=Path(__file__).resolve().parent;up=Path('/home/ruud/reference/ghc/nofib/real/compress2')
for filename in ['Main.hs','Encode.hs','WriteRoutines.hs','NofibUtils.hs','Makefile']:(p/filename).write_bytes((up/filename).read_bytes())
source=(p/'Main.hs').read_text();assert source.count('module Main (main)\nwhere')==1
(p/'Kernel.hs').write_text(source.replace('module Main (main)\nwhere','module Kernel where',1))
(p/'Observer.hs').write_text('''module Observer where
import qualified Kernel
import System.Environment
import System.IO
main=do
 hSetBinaryMode stdin True
 hSetBinaryMode stdout True
 [cut]<-getArgs
 input<-getContents
 putStr(Kernel.compress(take(max 0(length input-read cut))input))
''')
for name,main,args in [('original','Main.hs',[]),('observer','Observer.hs',['-main-is','Observer'])]:
 with(p/(name+'-reference-build.log')).open('w')as log:
  subprocess.run(['/usr/bin/ghc','-O2','-fforce-recomp',*args,'-outputdir',str(p/(name+'-reference-build')),'-i'+str(p),'-o',str(p/name),str(p/main)],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
def signed_hash(data):
 value=0
 for byte in data:value=(31*value+byte)&((1<<64)-1)
 return value-(1<<64)if value>=1<<63 else value
metadata=[]
for profile,input_suffix,output_suffix,timeout,memory in [('smoke','faststdin','faststdout',30,1024**3),('normal','stdin','stdout',600,4*1024**3),('large','slowstdin','slowstdout',3600,8*1024**3)]:
 data=(up/('compress2.'+input_suffix)).read_bytes()
 def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
 result=subprocess.run([str(p/'original')],input=data,capture_output=True,check=True,timeout=timeout,preexec_fn=limits)
 assert result.stdout==(up/('compress2.'+output_suffix)).read_bytes()
 (p/(profile+'.input')).write_bytes(data);(p/(profile+'.output')).write_bytes(result.stdout)
 records=[];hashes=[];out=p/(profile+'-cuts');out.mkdir(exist_ok=True)
 for cut in range(31):
  value=subprocess.run([str(p/'observer'),str(cut)],input=data,capture_output=True,check=True,timeout=30,preexec_fn=limits).stdout
  assert value[:3]==bytes([31,157,144]);hashes.append(signed_hash(value))
  (out/f'cut-{cut:02d}.bin').write_bytes(value)
  records.append({'cut':cut,'bytes':len(value),'sha256':hashlib.sha256(value).hexdigest(),'hash':hashes[-1]})
 expected=list(map(int,result.stdout.splitlines()));assert len(expected)==500 and all(value==hashes[i%31]for i,value in enumerate(expected,1))
 metadata.append({'profile':profile,'input_bytes':len(data),'input_sha256':hashlib.sha256(data).hexdigest(),'source_iterations':500,'timeout':timeout,'memory_bytes':memory,'cuts':records})
 print('PASS original500hashfixture andall31compressedbytefixtures',profile,flush=True)
(p/'reference-metadata.json').write_text(json.dumps({'compiler':subprocess.check_output(['/usr/bin/ghc','--version'],text=True).strip(),'profiles':metadata},indent=2)+'\n')
