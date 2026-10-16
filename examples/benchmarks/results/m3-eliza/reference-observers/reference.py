from pathlib import Path
import subprocess,resource,json
r=Path(__file__).resolve().parent
source=(r/'Main.hs').read_text();at=source.index('import Control.Monad');source=source[:at]+'module Kernel where\n\n'+source[at:];(r/'Kernel.hs').write_text(source)
(r/'DataObserver.hs').write_text('''module Main where
import Kernel
main=do
 print respMsgs
 print repeatMsgs
 print conjugates
''')
(r/'SessionObserver.hs').write_text('''module Main where
import Kernel
import System.Environment
main=do
 [arg]<-getArgs
 input<-getContents
 putStr(session initial[](filter(not.null)(map(words.trim)(take(read arg)(lines input)))))
''')
for source,exe in [('Main.hs','original'),('DataObserver.hs','data-observer'),('SessionObserver.hs','session-observer')]:
 with(r/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,source],cwd=r,stdout=log,stderr=subprocess.STDOUT,check=True)
def bounded():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
raw=subprocess.check_output([str(r/'data-observer')],text=True);(r/'data-observer.output').write_text(raw)
import ast;responses,repeated,conjugates=[ast.literal_eval(line)for line in raw.splitlines()];(r/'data.json').write_text(json.dumps(dict(responses=responses,repeated=repeated,conjugates=conjugates),indent=2)+'\n')
stdin=(r/'eliza.stdin').read_bytes()
for profile,n in [('smoke',20),('fast',1300),('normal',13000),('large',65000)]:
 raw=subprocess.check_output([str(r/'original'),str(n)],input=stdin,timeout=180,preexec_fn=bounded)
 if profile!='smoke':assert raw==(r/('eliza.'+('faststdout'if profile=='fast'else'slowstdout'if profile=='large'else'stdout'))).read_bytes()
 (r/(profile+'.lengths')).write_bytes(raw);print('PASS complete original lengths',profile,n,flush=True)
for prefix in range(20):
 raw=subprocess.check_output([str(r/'session-observer'),str(prefix)],input=stdin,timeout=180,preexec_fn=bounded);(r/(str(prefix)+'.session')).write_bytes(raw)
print('Recorded every original demand-selected conversation prefix0..19')
