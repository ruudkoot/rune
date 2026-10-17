from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;d=p/'observer-source';d.mkdir(exist_ok=True)
s=(p/'source/Main.lhs').read_text().replace('> module Main (main) where','> module Program where\n> import qualified Recorder')
assert '> output oc e@(MkEnv _ _ Stdout)    =  oc (void . evaluate . hash) e'in s
s=s.replace('> output oc e@(MkEnv _ _ Stdout)    =  oc (void . evaluate . hash) e','> output oc e@(MkEnv _ _ Stdout)    =  oc (Recorder.record Nothing) e')
s=s.replace('> output oc e@(MkEnv _ _ (File f))  =  oc (appendFile f) e','> output oc e@(MkEnv _ _ (File f))  =  oc (Recorder.record (Just f)) e')
(d/'Program.lhs').write_text(s);shutil.copy(p/'source/NofibUtils.hs',d/'NofibUtils.hs')
(d/'Recorder.hs').write_text('''module Recorder where
import Data.IORef
import System.IO.Unsafe(unsafePerformIO)
import Control.Exception(evaluate)
import NofibUtils(hash)
storage :: IORef [(Maybe String,String)]
storage=unsafePerformIO(newIORef [])
{-# NOINLINE storage #-}
record path text=do
 _<-evaluate(hash text)
 modifyIORef' storage ((path,text):)
reset=writeIORef storage []
collect=reverse <$> readIORef storage
''')
(d/'Observer.hs').write_text('''module Main where
import qualified Program as P
import qualified Recorder as R
import System.Environment
import NofibUtils(hash)
import Data.Word(Word64)
main=do
 [mode,file,out]<-getArgs
 input<-unlines . words <$> readFile file
 R.reset
 if mode=="aux"then P.do_auxfns P.stop P.defaultEnv else P.parse_args P.defaultEnv input
 chunks<-R.collect
 writeFile(out++".chunks")(unlines[show text|(_,text)<-chunks])
 writeFile(out++".channels")(unlines[maybe "-" id channel|(channel,_)<-chunks])
 writeFile(out++".hashes")(unlines[show(fromIntegral(hash text)::Word64)|(_,text)<-chunks])
 writeFile(out++".text")(concatMap snd chunks)
 print(length chunks,sum(map(length.snd)chunks))
''')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
cases={
 'default':(p/'source/mkhprog.stdin').read_text(),
 'aux':'',
 'empty':'',
 'one-int':'-a Int\n',
 'boolean':'-b Bool\n+c Bool\n',
 'string':'-s String\n',
 'literate':'-l -m Example -a Int -b Bool +c Bool -s String\n',
 'module-inline':'-mExample -a Int\n',
 'file':'-o generated.hs -m Alternate -a Int\n',
}
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
records=[]
for name,contents in cases.items():
 file=p/(name+'.input');file.write_text(contents)
 r=subprocess.run([str(d/'observer'),'aux'if name=='aux'else'normal',str(file),str(p/name),'+RTS','-M256m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
 (p/(name+'.observe')).write_bytes(r.stdout);assert not r.stderr
 chunks=[json.loads(row)for row in(p/(name+'.chunks')).read_text().splitlines()]
 assert ''.join(chunks)==(p/(name+'.text')).read_text()
 record=dict(name=name,chunks=len(chunks),characters=sum(map(len,chunks)),observation=r.stdout.decode().strip());records.append(record);print(record,flush=True)
 if name=='aux':
  constants=[chunks[i][:-1]for i in range(0,len(chunks),2)]
  assert len(constants)==4
  (p/'aux-constants.json').write_text(json.dumps(constants,indent=2)+'\n')
(p/'observer-metadata.json').write_text(json.dumps(records,indent=2)+'\n')
