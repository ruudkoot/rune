from pathlib import Path
import subprocess,shutil,json,struct
p=Path(__file__).resolve().parent;d=p/'observer-source';d.mkdir(exist_ok=True)
for f in(p/'real/source').glob('*.hs'):
 if f.name in ['Main.hs','Bah.hs']:continue
 text=f.read_text()
 if f.name=='Interval.hs':
  first=text.index('module Interval(');end=text.index('where',first);text=text[:first]+'module Interval '+text[end:]
 if f.name=='Oct.hs':text=text.replace('module Oct (octcsg) where','module Oct where')
 if f.name=='Quad.hs':text=text.replace('module Quad(quadoct) where','module Quad where')
 if f.name=='Csg.hs':
  first=text.index('module Csg');end=text.index('where',first);text=text[:first]+'module Csg '+text[end:]
 (d/f.name).write_text(text)
source='''module Main where
import Types
import Interval
import Csg
import Oct
import Quad
import Raster
import Shapes
import Kolor
import Control.Exception
import Data.Char
import Data.Bits
import Data.Word
showI name value=case value of
 Pt a->putStrLn(name++" point "++show a)
 a :#: b->putStrLn(name++" range "++show a++" "++show b)
intervals=[Pt 0,Pt 2,(-2):#:3,1:#:4,(-5):#:(-1)]::[Interval Double]
main=do
 mapM_(\\(i,a)->mapM_(\\(j,b)->do
  showI("add "++show i++" "++show j)(a+b)
  showI("min "++show i++" "++show j)(min a b)
  putStrLn(unwords["compare",show i,show j,show(a<b),show(a>b),show(a<=b),show(a>=b)])) (zip[0..]intervals))(zip[0..]intervals)
 mapM_(\\(i,a)->showI("square "++show i)(sqr a))(zip[0..]intervals)
 let deadOct=error"must not inspect hidden octree"::Oct
 let q=qo deadOct(Q_Full white)
 print(case q of Q_Full _->True;_->False)
 let result=calc(Func(\\rgb _->(Pt 1,error"dead residual",rgb,False)))white(Pt 0,Pt 0,Pt 0)
 print(case result of(ans,_,_,changed)->ans>Pt 0 && not changed)
'''
(d/'Observer.hs').write_text(source)
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=120);(p/'interval-observations.reference').write_bytes(out)
print('PASS original interval arithmetic/comparison and dead-residual/hidden-octree controls')
