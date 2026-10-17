from pathlib import Path
import subprocess,shutil,json,hashlib
p=Path(__file__).resolve().parent;d=p/'source';up=p.parent/'pinned/nofib/spectral/minimax'
for f in up.iterdir():
 if f.is_file():shutil.copyfile(f,d/f.name)
with(d/'original-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
(d/'Observe.hs').write_text('''module Main where
import Board
import Game
import Prog
import Tree
testBoard=[[Empty,O,Empty],[Empty,X,Empty],[Empty,Empty,Empty]]
main=do
 putStr(prog "1")
 putStrLn("LENGTH "++show(length(prog "1")))
 print(map snd(alternate X max' min' testBoard))
 print[(i,j,static b)|i<-[1..3],j<-[1..3],b<-placePiece X testBoard(i,j)]
''')
with(d/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observe.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(d/'observer'),'+RTS','-M1g','-RTS'],cwd=d,timeout=60)
(p/'observer.stdout').write_bytes(raw);body=raw.split(b'LENGTH ')[0];(p/'game.txt').write_bytes(body)
lines=raw.split(b'LENGTH ')[1].decode().splitlines();assert int(lines[0])==len(body)
for n in [1,2,10]:
 actual=subprocess.check_output([str(d/'original'),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=60);assert actual==b''
meta=dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),options=['-O2','-rtsopts'],nofib_revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',original_repetitions_checked=[1,2,10],original_stdout='empty',complete_game_length=len(body),game_sha256=hashlib.sha256(body).hexdigest(),observer=lines[1:])
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n');print(raw.decode());print(json.dumps(meta,indent=2))
