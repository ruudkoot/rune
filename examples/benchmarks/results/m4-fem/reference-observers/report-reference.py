from pathlib import Path
import shutil,subprocess,resource,json,hashlib
p=Path(__file__).resolve().parent;d=p/'report-observer-source'
shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('original','*.hi','*.o'),dirs_exist_ok=True)
f=d/'Basics.hs';text=f.read_text().replace('import Data.Array','import Data.Array\nimport Numeric(showFFloat)\n')
old="ns = dropWhile ((==) ' ') (show x)"
new="""ns = render x"""
assert text.count(old)==2;text=text.replace(old,new)
text+='''\nrender :: (Show a) => a -> String
render x = if any (\\c -> c=='.'||c=='e'||c=='E') raw
           then showFFloat (Just 9) (realToFrac (read raw :: Float) :: Double) ""
           else raw
 where raw=dropWhile (==' ') (show x)
'''
f.write_text(text)
f=d/'Main.hs';text=f.read_text().replace('main = do','main = do',1);text=text.replace('salt s >>= evaluate . hash . process','salt s >>= putStr . process')
assert 'evaluate . hash . process'not in text;f.write_text(text)
patch=subprocess.run(['diff','-u',str(p/'source/Basics.hs'),str(d/'Basics.hs')],capture_output=True)
(p/'fixed-format.patch').write_bytes(patch.stdout)
with(p/'report-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','report-observer','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for file in ['data.0','data.1','data.2','fem.stdin']:
 r=subprocess.run([str(d/'report-observer'),'1'],input=(d/file).read_bytes(),capture_output=True,timeout=120,preexec_fn=cap,check=True)
 (p/(file+'.report')).write_bytes(r.stdout);(p/(file+'.report-stderr')).write_bytes(r.stderr)
 records.append(dict(input=file,bytes=len(r.stdout),sha256=hashlib.sha256(r.stdout).hexdigest()))
 print(records[-1],flush=True)
(p/'report-reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
