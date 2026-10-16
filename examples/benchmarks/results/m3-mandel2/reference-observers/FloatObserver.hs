module Main where
import Kernel
import GHC.Float
import Numeric
import Data.Char
bits x=map toUpper(showHex(castFloatToWord32 x)"")
points=[(0,0),(1,1),(50,25),(100,50),(149,99),(150,99),(150,100),(200,100)]
steps p q k x y=if k+1==num_cols then [] else
 let xn=new_x x y p;yn=new_y x y q;r=radius xn yn
 in (k+1,xn,yn,r):if r>fromIntegral m then [] else steps p q(k+1)xn yn
main=mapM_(\(x,y)->do
 let p=np x;q=nq y
 putStrLn(unwords["point",show x,show y,bits p,bits q,show(point_colour(x,y))])
 mapM_(\(k,a,b,r)->putStrLn(unwords["step",show k,bits a,bits b,bits r]))(steps p q 0 0 0))points
