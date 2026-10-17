from pathlib import Path
import shutil,subprocess,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib';records=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for kind,limit,profiles in [
 ('gc',50,[('smoke',2),('normal',14),('large',16)]),
 ('real',10,[('smoke',2),('normal',4),('large',7)])]:
 d=p/('source-'+kind);shutil.copytree(up/kind/'linear',d,dirs_exist_ok=True)
 with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 for name,n in profiles:
  start=time.monotonic();r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
  (p/(kind+'-'+name+'.stdout')).write_bytes(r.stdout);(p/(kind+'-'+name+'.stderr')).write_bytes(r.stderr)
  fixture=(d/('linear'+('.fast'if name=='smoke'else'.slow'if name=='large'else'.')+'stdout'))
  record=dict(source=kind,profile=name,n=n,maxiters=limit,source_repetitions=200 if kind=='real'else 1,fixture_present=fixture.exists(),fixture_match=r.stdout==fixture.read_bytes()if fixture.exists()else None,bytes=len(r.stdout),elapsed_seconds=time.monotonic()-start)
  records.append(record);print(record,flush=True)
 # Separate observer compiles identical solver modules, exporting the demanded
 # counter/error/residual metrics used by source output and stopping.
 (d/'Observer.hs').write_text("""module Main where
import qualified Cg
import qualified Matrix as M
import qualified Input as I
import qualified Matlib as P
import qualified Misc
import System.Environment
main = do
 [text,limitText] <- getArgs
 let n=read text
 let a=I.a_hard n
 let soln=I.x1 n
 let b=M.mvmult a soln
 let conv (Cg.Cg_stateC _ r _ _ _) = sqrt(M.norm r) < 0.0000004
 let states=Misc.takeuntil conv(take(read limitText)(Cg.cgiters P.scale(P.precond 0)a b))
 mapM_ (\\(Cg.Cg_stateC x r _ _ cnt)->putStrLn(unwords[show cnt,show(M.norm(M.vsub x soln)),show(M.norm r)]))states
""")
 with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 for name,n in profiles:
  r=subprocess.run([str(d/'observer'),str(n),str(limit),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
  (p/(kind+'-'+name+'.metrics')).write_bytes(r.stdout);print(kind,name,'states',len(r.stdout.splitlines()),flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
