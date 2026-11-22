-- Report 4.5.5, Rule 1: a group with a non-simple pattern binding is restricted.
module Main (main) where

(f, g) = ((+), (-))

main :: IO ()
main = print (f (1 :: Int) 2, f (1 :: Double) 2)
