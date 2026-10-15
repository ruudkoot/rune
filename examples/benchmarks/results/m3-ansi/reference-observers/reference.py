"""Reproduce the original acquisition, without instrumenting the Haskell program."""
from pathlib import Path
import subprocess
p=Path(__file__).parent
source=Path('/home/ruud/reference/ghc/nofib/spectral/ansi/Main.hs')
subprocess.run(['ghc','-O2','-outputdir',str(p/'build'),'-o',str(p/'original'),str(source)],check=True)
for n in [0,1,2,3,150,400,900]:
    result=subprocess.run([str(p/'original'),str(n)],input=b'',capture_output=True,check=True,timeout=30)
    (p/(str(n)+'.stdout')).write_bytes(result.stdout)
    print(n,len(result.stdout))
