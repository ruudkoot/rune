module Main where
import KernelPic
import PicType
import Consts
import Data.Array
import NofibUtils
import System.Environment
numbers name values=putStrLn(name++" "++unwords(map show values))
emit particles k=do
 let initial=initParticles particles
 let phi=initPhi initial
 let(dt,grid,(positions,velocities))=timeStep initial phi 0.001 0 k
 putStrLn("step "++show k)
 numbers "dt" [dt]
 numbers "phi"(elems grid)
 numbers "positions"(concatMap(\(x,y)->[x,y])positions)
 numbers "velocities"(concatMap(\(x,y)->[x,y])velocities)
main=do
 [arg]<-getArgs
 let n=read arg
 putStrLn("pic "++pic n)
 putStrLn("hash "++show(hash(arg++pic n)))
 mapM_(emit n)[0..10]
