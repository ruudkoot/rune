from pathlib import Path
import subprocess,json,ast
p=Path(__file__).resolve().parent
fields=['t'+str(i)for i in range(4)]+['p'+str(i)for i in range(25)]+['x']
source=r'''module Fingerprints where
import qualified Main as N
import Types
import GHC.Float(castFloatToWord32)
point(Pt x y z)=map castFloatToWord32[x,y,z]
matrix(Tfo a b c d e f g h i j k l)=map castFloatToWord32[a,b,c,d,e,f,g,h,i,j,k,l]
kind(A _ _ _ _ _ _ _ _)=0::Int
kind(C _ _ _ _ _ _)=1
kind(G _ _ _ _ _ _ _ _ _)=2
kind(U _ _ _ _ _)=3
fingerprint(Nuc FIELDS)=(kind x,concatMap matrix[t0,t1,t2,t3])
atoms v@(N.Var i t n)=(i,fingerprint n,map(point . N.absolute_pos v)(N.list_of_atoms n))
main=mapM_(print . map atoms)(N.pseudoknot "1")
'''
source=source.replace('FIELDS',' '.join(fields))
records=[]
for mode in ['on-demand','shared']:
 w=p/mode;(w/'Fingerprints.hs').write_text(source)
 cmd=['ghc','-O2','-cpp','-rtsopts','-fforce-recomp']+(['-DUSE_HARTEL_LAZINESS']if mode=='shared'else[])+['-main-is','Fingerprints.main','Fingerprints.hs','Main.hs','-o','observe-fingerprints']
 with(w/'fingerprints-build.log').open('w')as out:r=subprocess.run(cmd,cwd=w,stdout=out,stderr=subprocess.STDOUT)
 assert r.returncode==0
 r=subprocess.run(['./observe-fingerprints','+RTS','-M1g','-RTS'],cwd=w,capture_output=True,timeout=120)
 (w/'fingerprints.reference').write_bytes(r.stdout);(w/'fingerprints.stderr').write_bytes(r.stderr)
 assert r.returncode==0
 data=[ast.literal_eval(l)for l in r.stdout.decode().splitlines()];assert len(data)==50
 records.append(dict(mode=mode,exit=r.returncode,solutions=len(data),bytes=len(r.stdout)))
 print(records[-1],flush=True)
assert(p/'on-demand/fingerprints.reference').read_bytes()==(p/'shared/fingerprints.reference').read_bytes()
(p/'fingerprints-reference-exits.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS original on-demand and shared exact conformation choices and coordinates agree')
