from pathlib import Path
import shutil,subprocess,json,resource
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
(d/'Observer.hs').write_text('''module Main where
import Board
import Move
import Problem
main = do
 input <- getContents
 let (bd,(c,n))=readProblem input
 putStr (showBoard bd)
 putStrLn (show (kingincheck White bd,kingincheck Black bd))
 mapM_ (\\(m,b)->putStrLn(showMoveInFull m) >> putStr(showBoard b)) (moveDetailsFor c bd)
''')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
cases={}
def position(pieces,goal):
 rows=[['-']*8 for _ in range(8)]
 for file,rank,char in pieces:rows[8-rank][file-1]=char
 return '\n'.join(' '.join(row)for row in rows)+'\n\n'+goal+'\n'
cases['mate']=position([(1,8,'K'),(3,6,'k'),(2,7,'q')],'Black to play and mate in 1')
cases['stalemate']=position([(1,8,'K'),(3,6,'k'),(3,7,'q')],'Black to play and mate in 1')
cases['promotion']=position([(8,1,'k'),(8,8,'K'),(1,7,'p')],'White to play and mate in 1')
cases['pinned-rook']=position([(1,1,'k'),(1,2,'r'),(1,8,'R'),(8,8,'K')],'White to play and mate in 1')
cases['black-pawn-check']=position([(4,4,'k'),(3,5,'P'),(8,8,'K')],'White to play and mate in 1')
for name in ['heathcote3','kohtz','holzhausen','simple']:
 cases[name]=(d/'runtime_files'/(name+'.prob')).read_text()
caseout=p/'cases';caseout.mkdir(exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for name,text in cases.items():
 (caseout/(name+'.prob')).write_text(text)
 r=subprocess.run([str(d/'observer'),'+RTS','-M128m','-RTS'],cwd=d,input=text.encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
 (caseout/(name+'.moves')).write_bytes(r.stdout);print(name,len(r.stdout),flush=True)
