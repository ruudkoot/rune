from pathlib import Path
import subprocess,shutil,resource,json,heapq
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
s=(d/'Main.hs').read_text();old='module Main (main) -- event\nwhere {';assert old in s;(d/'Event.hs').write_text(s.replace(old,'module Event where {'))
(d/'Observer.hs').write_text('''module Main where
import qualified Event as E
import System.Environment
showState E.C_X='x'
showState E.C_L='L'
showState E.C_H='H'
main = do
 [mode,arg] <- getArgs
 let n=read arg
 if mode=="state" then putStr(E.f_benchmark_main n)
 else if mode=="deps" then mapM_ (putStrLn . unwords . map show . E.f_dependencies)[0..12]
 else mapM_ (\\(E.F_At t w s)->putStrLn(unwords[show t,show w,[showState s]])) (E.f_simulate E.c_ievents E.c_istate n)
''')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
connections={3:(0,0),4:(0,1),5:(3,1),6:(4,7),7:(5,6),8:(1,1),9:(8,6),10:(8,7),11:(9,12),12:(10,11)}
def nand(x,y):return'L'if x=='H'and y=='H'else'H'if x=='L'or y=='L'else'x'
def model(end):
 queue=[];sequence=0
 for wire,start,low,high in [(1,0,50,50),(0,25,100,100)]:
  for t in range(start,end+201,low+high):
   for time,value in [(t,'L'),(t+low,'H')]:heapq.heappush(queue,(time,sequence,wire,value));sequence+=1
 st=['x']*13;rows=[]
 while queue and queue[0][0]<end:
  t,_,wire,value=heapq.heappop(queue)
  if st[wire]==value:continue
  st[wire]=value;rows.append(f'{t} {wire} {value}\n')
  for target,(a,b)in connections.items():
   if wire in(a,b):heapq.heappush(queue,(t+3,sequence,target,nand(st[a],st[b])));sequence+=1
 return ''.join(st)+'\n',''.join(rows)
out=p/'cases';out.mkdir(exist_ok=True)
for n in [0,1,3,25,26,28,29,50,51,100,200,1000]:
 state,trace=model(n)
 for mode,want in [('state',state),('trace',trace)]:
  r=subprocess.run([str(d/'observer'),mode,str(n),'+RTS','-M128m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
  assert r.stdout==want.encode(),(n,mode);(out/(str(n)+'.'+mode)).write_bytes(r.stdout)
 print(n,len(trace.splitlines()),state.strip(),flush=True)
r=subprocess.run([str(d/'observer'),'deps','0'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
(out/'dependencies.txt').write_bytes(r.stdout)
r=subprocess.run([str(p/'source/original'),'10000','+RTS','-M128m','-RTS'],cwd=p/'source',stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
assert r.stdout==(p/'source/event.faststdout').read_bytes();(p/'original-fast.stdout').write_bytes(r.stdout);print('original FAST fixture MATCH',flush=True)
