module Main where
import Kernel
import System.Environment
values n = let count=n*(n+1)
               z i = 1+fromIntegral (i `mod` 7)/4
               row i = let a=if i==0 then 0 else -1-fromIntegral(i `mod` 3)/8
                           b=5+fromIntegral(i `mod` 5)/4
                           c=if i==count-1 then 0 else 0.5+fromIntegral(i `mod` 2)/8
                           r=a*z(i-1)+b*z i+c*z(i+1)
                       in (a,b,c,r)
           in chunks (n+1) [row i|i<-[0..count-1]]
chunks n []=[]
chunks n xs=take n xs:chunks n(drop n xs)
main=do
 [arg]<-getArgs
 mapM_ (putStrLn . unwords . map show) (f_solution (values(read arg)))
