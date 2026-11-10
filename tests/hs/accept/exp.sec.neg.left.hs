-- Report 3.5: a left section may begin with negation where its operator is at level 6: (-5 +), by ( lexp6 qop(l,6) ) (R10).
module Main (main) where

main :: IO ()
main = print ((-5 +) 1 :: Int)
