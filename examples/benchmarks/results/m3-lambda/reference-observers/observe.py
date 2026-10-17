from pathlib import Path
import subprocess,shutil,json
p=Path(__file__).resolve().parent;d=p/'observer-source';d.mkdir(exist_ok=True)
s=(p/'source/Main.hs').read_text();assert'module Main( main ) where'in s
(d/'Kernel.hs').write_text(s.replace('module Main( main ) where','module Kernel where'))
(d/'Observer.hs').write_text("""module Main where
import qualified Kernel as K
import Control.Monad.Trans.State.Strict
import Data.Functor.Identity
cases :: [(K.Env,K.Term)]
cases =
 [([],t) | t <- [K.iftrue,K.iffalse,K.Incr,K.Con (-7),
   K.App K.a1 (K.Con 12), K.App K.aa (K.Con 9),
   K.App (K.Lam "x" (K.Con 3)) (K.Var "undefined"),
   K.IfZero (K.Lam "x" (K.Var "x")) (K.Con 9) (K.Con 8),
   K.App (K.Lam "x" (K.App (K.Lam "x" (K.Var "x")) (K.Con 7))) (K.Con 2),
   K.App (K.Lam "x" (K.App (K.Lam "f" (K.App (K.Var "f") (K.Con 0)))
     (K.Lam "z" (K.Var "x")))) (K.Con 23)]]
 ++ [([],K.App K.sum0 (K.Con n)) | n <- [0..20]]
 ++ [([("outer",K.Con 91)],K.Add (K.Con 4) (K.Thunk (K.Var "outer") [("outer",K.Con 13)])),
     ([("x",K.Con 10)],K.Lam "y" (K.Add (K.Var "x") (K.Var "y")))]
main = mapM_ run (zip [0..] cases)
 where run (i,(e,t)) = do
        let K.Id direct=K.simpleEval e t
        let (monad,env)=runState (K.traverseTerm t :: State K.Env K.Term) e
        putStrLn (show i ++ "\\t" ++ K.pp(runIdentity direct) ++ "\\t" ++ K.pp monad ++ "\\t" ++ K.ppenv env)
""")
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(d/'observer')],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=True)
(p/'terms.reference').write_bytes(r.stdout);assert len(r.stdout.splitlines())==33
print('33 original direct/state terms observed')
