module Main where
import Data.Complex
samples=[(3,4),(0,4),(1e200,1e200),(1e-200,1e-200),(1e-200,0)]::[(Double,Double)]
main=mapM_(\(a,b)->putStrLn(unwords[show a,show b,show(magnitude(a:+b))]))samples
