from pathlib import Path
import subprocess,resource
p=Path(__file__).resolve().parent;d=p/'observer-source'
(d/'SolveObserver.hs').write_text('''module Main where
import Problem
import Solution
main = getContents >>= \\input -> let (bd,(c,n))=readProblem input in putStr (solve bd c n)
''')
with(d/'solve-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-o','solve-observer','SolveObserver.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for name in ['mate','stalemate','promotion','pinned-rook','black-pawn-check','simple']:
 r=subprocess.run([str(d/'solve-observer'),'+RTS','-M128m','-RTS'],cwd=d,input=(p/'cases'/(name+'.prob')).read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
 (p/'cases'/(name+'.solution')).write_bytes(r.stdout);print(name,len(r.stdout),flush=True)
r=subprocess.run([str(p/'source/original'),'runtime_files/simple.prob','+RTS','-M128m','-RTS'],cwd=p/'source',stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True)
(p/'smoke-small.stdout').write_bytes(r.stdout);print('small smoke',len(r.stdout))
