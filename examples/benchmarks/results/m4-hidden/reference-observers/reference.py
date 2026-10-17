from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/hidden';d=p/'source';d.mkdir(exist_ok=True)
for file in up.iterdir():
 if file.is_file():shutil.copyfile(file,d/file.name)
shutil.copytree(up/'runtime_files',d/'runtime_files',dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
with(d/'original-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
metadata=[]
for profile,file in [('smoke','houses.plate'),('normal','rad.plate'),('large','four.plate')]:
 r=subprocess.run([str(d/'original'),'runtime_files/'+file,'+RTS','-K1m','-M1g','-RTS'],cwd=d,input=(d/'hidden.stdin').read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 assert r.stdout==b''and r.stderr==(d/'hidden.stderr').read_bytes()
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 metadata.append(dict(profile=profile,file=file,repetitions=20,polygons=len((d/'runtime_files'/file).read_text().splitlines()),stderr_bytes=len(r.stderr)));print(metadata[-1],flush=True)
o=p/'observer-source';o.mkdir(exist_ok=True)
for file in d.iterdir():
 if file.suffix in{'.hs','.lhs'}:shutil.copyfile(file,o/file.name)
f=o/'Numbers.hs';s=f.read_text();assert 'module Numbers(Number) where'in s;f.write_text(s.replace('module Numbers(Number) where','module Numbers where'))
f=o/'Hide.hs';s=f.read_text();assert 'module Hide(hiddenline) where'in s;f.write_text(s.replace('module Hide(hiddenline) where','module Hide where'))
(o/'Observer.hs').write_text('''module Main where
import Numbers
import Vectors
import Hide
import EdgePlate
import Geometric
import Postscript
import NofibUtils
import GHC.Float(castFloatToWord32)
import System.Environment
word(Tolerant x)=show(castFloatToWord32 x)
point v=unwords(map word[x v,y v,z v])
edge e=point(s e)++" "++point(t e)
main=do
 [file,out]<-getArgs
 input<-readFile file
 let object=map read(lines input)
 let view=vec[2,10,3]
 let rotated=rot view object
 let(base,factor)=getExtremes(concat rotated)
 let raw=hideObj(makeObject rotated)
 let result=scale factor base raw
 let text=draw result
 if text/=hiddenline view object then error "observer pipeline differs"else return()
 writeFile(out++".ps")text
 writeFile(out++".edges")(unlines(map edge result))
 writeFile(out++".raw-edges")(unlines(map edge raw))
 writeFile(out++".rotated")(unlines(map point(concat rotated)))
 putStrLn(unwords["result",show(length result),show(length text),show(hash text)] )
 putStrLn("scale "++point base++" "++word factor)
''')
with(o/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for profile,file in [('smoke','houses.plate'),('normal','rad.plate'),('large','four.plate')]:
 raw=subprocess.check_output([str(o/'observer'),str(d/'runtime_files'/file),str(p/profile),'+RTS','-K1m','-M1g','-RTS'],cwd=o,timeout=600,preexec_fn=cap);(p/(profile+'.observe')).write_bytes(raw);print(raw.decode(),flush=True)
(o/'NumbersProbe.hs').write_text('''module Main where
import Numbers
import Vectors
import GHC.Float(castFloatToWord32)
samples :: [(String,Number,Number)]
samples=[("zero-zero",read "0",read "0"),("eps-zero",read "0.0001",read "0"),("zero-eps",read "0",read "0.0001"),("minus-eps-zero",read "-0.0001",read "0"),("below-eps",read "0.00009999",read "0")]
word(Tolerant x)=show(castFloatToWord32 x)
emit(name,a,b)=putStrLn(unwords[name,word a,word b,show(a==b),show(a/=b),show(a<b),show(a<=b),show(a>b),show(a>=b),show(compare a b),show(vec[a,0,0]==vec[b,0,0]),show(vec[a,0,0]/=vec[b,0,0])])
main=mapM_ emit samples
''')
with(o/'numbers-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','numbers','NumbersProbe.hs'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(o/'numbers')],cwd=o,timeout=30);(p/'numbers.observe').write_bytes(raw);print(raw.decode(),flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),nofib_revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',profiles=metadata,scope='Unmodified originals match stored stderr and empty stdout; export-only observers add complete vector/edge demand beyond two-dimensional rendering'),indent=2)+'\n')
