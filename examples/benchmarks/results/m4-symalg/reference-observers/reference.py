from pathlib import Path
import subprocess,resource,time,json
p=Path(__file__).resolve().parent
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,stem in [('source-fast','fast'),('normal',''),('source-slow','slow')]:
 suffix='.'+stem if stem else'.'
 inp=p/'source'/('symalg.'+stem+'stdin');expected=p/'source'/('symalg.'+stem+'stdout')
 start=time.monotonic()
 result=subprocess.run([str(p/'source/original'),'+RTS','-M512m','-RTS'],input=inp.read_bytes(),capture_output=True,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(result.stdout);(p/(profile+'.stderr')).write_bytes(result.stderr)
 assert result.stdout==expected.read_bytes(),profile
 records.append(dict(profile=profile,bytes=len(result.stdout),seconds=time.monotonic()-start))
 print(records[-1],flush=True)
(p/'source-profile-results.json').write_text(json.dumps(records,indent=2)+'\n')
source='''module Main where
import qualified RealM as R
output label value = putStrLn (label++" "++show value)
main = do
'''
cases=[]
for a in [-25,-3,-1,0,1,2,3,10,123]:
 for n in [2,1,0,-1,-4,-10,-25]:
  cases.append(('integer/'+str(a)+'/'+str(n),'R.evalReal (R.int2Real ('+str(a)+')) ('+str(n)+')'))
for a in [0,1,2,3,4,10,123]:
 for n in [0,-1,-4,-10,-25]:
  cases.append(('sqrt/'+str(a)+'/'+str(n),'R.evalReal (R.sqrtReal (R.int2Real '+str(a)+')) ('+str(n)+')'))
for a,b in [(0,2),(2,0),(2,3),(-2,3),(123,7),(-5,-2)]:
 for op in ['addReal','subReal','mulReal','divReal']:
  if op=='divReal'and b==0:continue
  for n in [0,-4,-10]:
   cases.append((op+'/'+str(a)+'/'+str(b)+'/'+str(n),'R.evalReal (R.'+op+' (R.int2Real ('+str(a)+')) (R.int2Real ('+str(b)+'))) ('+str(n)+')'))
source+=''.join('  output "'+label+'" ('+call+')\n'for label,call in cases)
(p/'source/Observer.hs').write_text(source)
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-main-is','Main','-o','observer','Observer.hs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'real-observations.reference').open('w')as log:subprocess.run([str(p/'source/observer')],stdout=log,stderr=subprocess.STDOUT,timeout=120,preexec_fn=cap,check=True)
print('Original real observations',len(cases),flush=True)
