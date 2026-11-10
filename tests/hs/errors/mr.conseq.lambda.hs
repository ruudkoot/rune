-- Report 4.5.5: the same function by pattern syntax is restricted without a signature.
module Main (main) where

f = \x -> \y -> x + y

main :: IO ()
main = print (f (1 :: Int) 2, f 1.5 2)
