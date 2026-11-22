-- Report 9.5: exp(i) -> exp(i+1) [qop(n,i) exp(i+1)]: non-associative operators of one level do not chain.
module Main (main) where

main :: IO ()
main = print (1 == 1 == True)
