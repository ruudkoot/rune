from pathlib import Path
import subprocess,resource,math,json
ref=Path(__file__).resolve().parent
source=(ref/'Main.hs').read_text()
observer=source.replace('module Main (main) where','{-# LANGUAGE BangPatterns #-}\nmodule Main (main) where\nimport Data.Word\nimport Numeric\nimport Data.Char')
observer=observer.replace(':: (Integer -> Integer -> a)',':: (Show a, Show b) => (Integer -> Integer -> a)',1)
observer=observer.replace('integerbench :: (Integer -> Integer -> a)','integerbench :: Show a => (Integer -> Integer -> a)')
observer=observer.replace('intbench :: (Int -> Int -> a)','intbench :: Show a => (Int -> Int -> a)')
observer=observer[:observer.index('\nseqlist []')]+'''
seqlist :: Show a => [a] -> IO ()
seqlist xs = let
  value x = case show x of "True" -> 1; "False" -> 0; text -> read text :: Integer
  loop [] !n !h = putStrLn (show n ++ ":" ++ map toUpper (showHex h ""))
  loop (x:rest) !n !h = x `seq` loop rest (n+1 :: Int) (h*1664525+fromInteger(value x) :: Word64)
  in loop xs 0 (1013904223 :: Word64)
'''
(ref/'Observer.hs').write_text(observer)
for filename,exe in [('Main.hs','original'),('Observer.hs','observer')]:
 with(ref/(exe+'-build.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',exe,filename],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(600,600))
mask=(1<<64)-1
ops=[lambda a,b:a+b,lambda a,b:a-b,lambda a,b:a*b,lambda a,b:a//b,lambda a,b:a%b,lambda a,b:(-1 if(a<0)^(b<0)else 1)*(abs(a)//abs(b)),lambda a,b:a-((-1 if(a<0)^(b<0)else 1)*(abs(a)//abs(b)))*b,math.gcd,math.lcm,lambda a,b:a==b,lambda a,b:a<b,lambda a,b:a<=b,lambda a,b:a>b,lambda a,b:a>=b]
meta=[]
for profile,step in [('smoke',700000001),('normal',4500001),('large',2000001)]:
 args=['-2100000000',str(step),'2100000000'];original=subprocess.run([str(ref/'original')]+args,capture_output=True,preexec_fn=bounded,timeout=615);assert original.returncode==0 and original.stdout==b'',(profile,original.stderr)
 raw=subprocess.check_output([str(ref/'observer')]+args,preexec_fn=bounded,timeout=615);(ref/(profile+'.expected')).write_bytes(raw)
 values=range(-2100000000,2100000001,step);count=len(values)**2
 expected=[]
 for op in ops:
  h=1013904223
  for a in values:
   for b in values:h=(h*1664525+int(op(a,b)))&mask
  expected.extend([str(count)+':'+format(h,'X')]*2)
 assert raw.decode().splitlines()==expected,(profile,raw,expected)
 meta.append(dict(profile=profile,arguments=args,grid_size=len(values),pairs_per_pass=count,total_passes=28,original_exit=original.returncode,original_stdout='empty',observer='Show-only value observer; source operation order and separate machine/arbitrary passes retained',independent='Python exact integer model; selected values/products fit signed64'))
 print('PASS complete original and independent digest',profile,'grid',len(values),flush=True)
(ref/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
