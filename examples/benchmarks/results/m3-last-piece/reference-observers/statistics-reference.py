from pathlib import Path
import subprocess,json
r=Path(__file__).resolve().parent;w=r/'observer-src';source=(w/'PrefixObserver.hs').read_text()
source=source.replace('main=do','''stats :: Solution -> (Int,Int,Int)
stats(Soln _)=(1,0,1)
stats(Fail _ _)=(1,1,0)
stats(Choose children)=foldl (\\(a,b,c)(x,y,z)->(a+x,b+y,c+z))(1,0,0)(map stats children)
main=do''')
source=source.replace('printDoc(display(search(1,2)Female board(drop(13-n)initialPieces)))','print(stats(search(1,2)Female board(drop(13-n)initialPieces)))')
(w/'StatisticsObserver.hs').write_text(source)
with(r/'statistics-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',str(r/'statistics-observer'),'StatisticsObserver.hs'],cwd=w,stdout=log,stderr=subprocess.STDOUT,check=True)
records=[]
for n in [0,2,8,13]:
 raw=subprocess.check_output([str(r/'statistics-observer'),str(n)],text=True,timeout=180);(r/(str(n)+'.statistics')).write_text(raw);records.append(dict(remaining=n,statistics=raw.strip()));print('Original complete tree statistics',n,raw.strip(),flush=True)
(r/'statistics-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
