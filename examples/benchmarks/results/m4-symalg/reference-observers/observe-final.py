from pathlib import Path
import subprocess,resource
p=Path(__file__).resolve().parent
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
source='''module Main where
import qualified RealM as R
import System.IO
output label value = putStrLn (label++" "++show value)
main = do
  hSetBuffering stdout LineBuffering
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
  if (op=='divReal'and b==0)or(a==0 and op in ['mulReal','divReal']):continue
  for n in [0,-4,-10]:
   cases.append((op+'/'+str(a)+'/'+str(b)+'/'+str(n),'R.evalReal (R.'+op+' (R.int2Real ('+str(a)+')) (R.int2Real ('+str(b)+'))) ('+str(n)+')'))
source+=''.join('  output "'+label+'" ('+call+')\n'for label,call in cases)
(p/'source/Observer.hs').write_text(source)
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-main-is','Main','-o','observer','Observer.hs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
with(p/'real-observations.reference').open('w')as log:subprocess.run([str(p/'source/observer')],stdout=log,stderr=subprocess.STDOUT,timeout=120,preexec_fn=cap,check=True)
print('Original real observations',len(cases),flush=True)
