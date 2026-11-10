-- Report 3.17.1: f 0 = 1 is (Num a, Num b) => a -> b, Eq by the superclass: used at two types.
module Main (main) where

f 0 = 1

g :: Int
g = f (0 :: Int)

h :: Double
h = f (0 :: Double)

main :: IO ()
main = return ()
