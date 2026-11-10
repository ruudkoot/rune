-- Report 3.17.1: f (n+1) = n is Integral a => a -> a: used at Int and Integer.
module Main (main) where

f (n + 1) = n

g :: Int
g = f 3

h :: Integer
h = f 3

main :: IO ()
main = return ()
