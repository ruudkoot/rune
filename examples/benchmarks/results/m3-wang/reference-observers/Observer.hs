module Main where
import Kernel
import System.Environment
main=do
 [n]<-getArgs
 mapM_ (putStrLn . unwords . map show) (f_solution (f_bigmatrix(read n)))
