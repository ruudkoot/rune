module Main where
import Fourier
import Complex_Vectors
import Data.Complex
import System.Environment
point z=unwords[show(realPart z),show(imagPart z)]
main=do
 [count,out]<-getArgs
 let n=read count
 let xs=[0..fromIntegral(n-1)]::[Double]
 let zs=map(:+0)xs
 let functions=[("fft",fft zs),("fftinv",fftinv zs),("dft",dft zs),("dftinv",dftinv zs),("sft",sft zs)]
 mapM_(\(name,result)->writeFile(out++"."++name)(unlines(map point result)))functions
 writeFile(out++".sct")(unlines(map show(sct xs)))
 putStrLn(show n)
