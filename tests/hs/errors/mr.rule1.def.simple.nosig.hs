-- Report 4.5.5, Rule 1: an unsigned simple pattern binding is restricted: f at Int and Double.
module Main (main) where

f = \x -> \y -> x + y

main :: IO ()
main = print (f (1 :: Int) 2, f (1 :: Double) 2)
