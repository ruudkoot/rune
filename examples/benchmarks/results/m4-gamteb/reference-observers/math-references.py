from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'observer-source'
cases=[]
for seed in[0.,.1,.5,1.]:cases.append(('random',[seed],f'let(a,b)=genRand {seed} in [a,b]'))
for position,direction in[
 ((0,0,0),(0,1,0)),((0,0,0),(1,0,0)),((0,25,0),(0,-1,0)),((0,0,.5),(0,1,1)),
 ((.5,0,0),(0,0,1)),((.5,0,0),(0,0,-1)),((.9,5,.1),(.3,.4,.5)),((0,0,0),(0,0,0))]:
 tupleHS=lambda values:'('+','.join('('+str(float(v))+')'for v in values)+')'
 cases.append(('distance',list(position+direction),f'let(d,s)=distSurf {tupleHS(position)} {tupleHS(direction)} in [d,fromIntegral s]'))
for seed in[0.,.5,.999]:cases.append(('isotropic',[seed],f'let(a,b,c)=isos {seed} in [a,b,c]'))
for direction,angle,seed in[((0,0,1),.25,.5),((0,1,0),.25,.5),((1,0,0),-.5,.1),((.3,.4,.5),.9,.9)]:
 cases.append(('rotate',list(direction)+[angle,seed],f'let(a,b,c)=rotas {tupleHS(direction)} ({angle}) {seed} in [a,b,c]'))
for energy in[.0005,.001,.511008,1.,6.,20.,25.]:
 cases.append(('xsect',[energy],f'let(i,(a,b,c,t))=xsectInterp {energy} in [fromIntegral i,a,b,c,t]'))
for energy in[.1,1.,1.16666667,2.,6.]:
 for random in[0.,.1,.5,.999]:cases.append(('klein',[energy,random],f'[klein {energy} {random}]'))
head='''module Main where
import Utils
import Pair
import Compton
import Distance
emit label args values=putStrLn(unwords(label:map show args)++" | "++unwords(map show values))
main=do
'''
for kind,args,expression in cases:head+=' emit "'+kind+'" ['+','.join('('+str(float(v))+')'for v in args)+'] ('+expression+')\n'
(d/'MathObserver.hs').write_text(head)
with(d/'math-observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','math-observer','MathObserver.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.check_output([str(d/'math-observer')],cwd=d,timeout=60)
(p/'math.references').write_bytes(r);(p/'math-cases.json').write_text(json.dumps([dict(kind=kind,args=args)for kind,args,_ in cases],indent=2)+'\n')
print(len(cases),'source math reference cases')
