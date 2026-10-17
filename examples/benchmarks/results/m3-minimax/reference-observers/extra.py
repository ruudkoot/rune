from pathlib import Path
import json,subprocess
p=Path(__file__).resolve().parent;d=p/'source';rows=json.loads((p/'cases.json').read_text());cases=[r['board']for r in rows]
(d/'Extra.hs').write_text('''module Main where
import Board
import Game
piece 'X'=X
piece 'O'=O
piece '.'=Empty
board s=map(map piece)[take 3 s,take 3(drop 3 s),drop 6 s]
emit s=let b=board s in putStrLn(s++":"++show(static b)++":"++show(bestMove X max' min' b)++":"++show(bestMove O min' max' b))
main=mapM_ emit '''+str(cases).replace("'",'"')+'\n')
with(d/'extra-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','extra','Extra.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(d/'extra'),'+RTS','-M1g','-RTS'],cwd=d,timeout=60);(p/'cases.stdout').write_bytes(raw)
assert raw.decode().splitlines()==[':'.join([r['board'],r['static'],r['max'],r['min']])for r in rows]
print('GHC and independent model agree on',len(rows),'complete board analyses')
