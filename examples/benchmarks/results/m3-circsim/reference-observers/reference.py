from pathlib import Path
import shutil,subprocess,json,resource,hashlib,difflib
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib';meta=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
for group in ['gc','spectral']:
 d=p/group;d.mkdir(exist_ok=True);source=up/group/'circsim'
 for file in source.iterdir():
  if file.is_file():shutil.copyfile(file,d/file.name)
 with(d/'original-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 (d/'Kernel.lhs').write_text((d/'Main.lhs').read_text().replace('> import System.Environment','> module Kernel where\n> import System.Environment',1))
 (d/'Observer.hs').write_text('''module Main where
import Kernel
import System.Environment
main=do
 [b,c]<-getArgs
 let values=run(read b)(read c)
 putStrLn("LENGTH "++show(length(show values)))
 print values
''')
 with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 for profile,bits,cycles in [('smoke',8,4),('normal',8,40),('large',8,200)]:
  fixture='circsim'+dict(smoke='.faststdout',normal='.stdout',large='.slowstdout')[profile];flags=['+RTS','-M1g']+(['-H30m']if group=='spectral'else[])+['-RTS']
  raw=subprocess.check_output([str(d/'original'),str(bits),str(cycles)]+flags,cwd=d,timeout=180,preexec_fn=cap);(d/(profile+'.stdout')).write_bytes(raw)
  if (d/fixture).exists():assert raw==(d/fixture).read_bytes()
  else:assert group=='gc' and raw==b''
  observed=subprocess.check_output([str(d/'observer'),str(bits),str(cycles),'+RTS','-M1g','-RTS'],cwd=d,timeout=180,preexec_fn=cap);(d/(profile+'.trace')).write_bytes(observed)
  row=dict(source=group,profile=profile,bits=bits,cycles=cycles,repetitions=97,stdout_bytes=len(raw),observer_bytes=len(observed),runtime_options=flags,fixture=fixture if (d/fixture).exists() else None,fixture_scope='stored upstream bytes' if (d/fixture).exists() else 'GC main returns unit without output; no upstream stdout fixture',source_sha256=hashlib.sha256((d/'Main.lhs').read_bytes()).hexdigest());meta.append(row);print(row,flush=True)
a=(p/'gc/Main.lhs').read_text();b=(p/'spectral/Main.lhs').read_text();(p/'source-variants.diff').write_text(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='gc/Main.lhs',tofile='spectral/Main.lhs')))
start=a.index('>   -- We save ourselfs');end=a.index('\n',a.index('>   return $!',start));normalized=a[:start]+'>   print (run (read num_bits) (read num_cycles))'+a[end:];assert normalized==b
(p/'core-equality.json').write_text(json.dumps(dict(scope='complete source equality after replacing only the GC main consumer/comment with the printed consumer',normalized_sha256=hashlib.sha256(b.encode()).hexdigest()),indent=2)+'\n');(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
