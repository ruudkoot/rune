from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'observer-source';d.mkdir(exist_ok=True)
src=(p/'source/Main.lhs').read_text();pos=src.index('> import')
(d/'Rewrite.lhs').write_text(src[:pos]+'> module Rewrite where\n'+src[pos:])
(d/'Observer.hs').write_text('''module Main where
import qualified Rewrite as R
import Data.List(sortOn)
render (R.Var n)=n
render (R.Func f xs)=f++"("++comma(map render xs)++")"
comma []=""
comma [x]=x
comma(x:xs)=x++","++comma xs
rules(R.Return xs)=xs
rules(R.Switch xs d)=concatMap (rules.snd) xs++rules d
main=do
 mapM_ (\\e->putStrLn(show(R.eqno e)++" "++render(R.lhs e)++"="++render(R.rhs e))) (sortOn R.eqno (rules R.group_completion))
 mapM_ (\\s->putStrLn(s++" -> "++render(R.simplify(R.super_reduce R.group_completion)(R.parse s)))) terms
terms=["E","a","I(a)","E*a","a*E","I(I(a))","I(a)*a","a*I(a)","(a*b)*c","I(a*b)","I((a*b)*c)","a*(I(a)*b)","I(a)*(a*b)","I(I(a*b))","I(E)","I(a)*(a*(b*I(b)))"]
''')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','Observer.hs','Rewrite.lhs','-o','observer'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=30)
(p/'theory-and-normalforms.reference').write_bytes(out)
print(out.decode())
