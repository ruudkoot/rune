-- Report 9.5: aexp -> ( qop(a,i) exp(i+1) ) | ( qop(r,i) rexp(i) ): not (* a + b).
module Main (main) where

main :: IO ()
main = print ((* 1 + 2) 3)
