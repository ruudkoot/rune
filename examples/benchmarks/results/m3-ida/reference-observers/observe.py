from pathlib import Path
import subprocess,json,random
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/ida';d=p/'observer-source';d.mkdir(exist_ok=True)
s=(up/'Main.hs').read_text().replace('module Main (main) -- ida','module Ida -- ida')
(d/'Ida.hs').write_text(s)
cases=[(seed,w,h,n)for seed in [0,6,42]for w,h in [(2,3),(2,4),(3,3)]for n in [0,1,5,20]]+[(6,3,4,100)]
(p/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
(d/'Observer.hs').write_text('''module Main where
import qualified Ida as I
pos (I.F_POS x y)="("++show x++","++show y++")"
squares xs=concatMap I.f_show_square xs
path(I.F_SEARCH _ _ _ ps)=concatMap pos ps
observe(seed,w,h,n)=
 let conf@(I.F_CONF hole tiles)=I.f_shuffle (I.f_goal w h) n (I.f_cons_rnd_gen seed)
     I.F_SOLUTION search count=I.f_solve_puzzle conf 7 (n+1)
     I.F_SEARCH bound depth _ ps=search
 in putStrLn(show(seed,w,h,n)++" "++I.f_show_pos hole++squares tiles++" | "++show bound++" "++show count++" "++show depth++" "++path search)
main=mapM_ observe '''+repr(cases).replace(' ','')+'\n')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-I'+str(up),'Observer.hs','Ida.hs','-o','observer'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer'),'+RTS','-M512m','-RTS'],cwd=d,timeout=120)
(p/'cases.reference').write_bytes(out);assert len(out.splitlines())==len(cases)
print('PASS original',len(cases),'full configuration/solution/path observations')
