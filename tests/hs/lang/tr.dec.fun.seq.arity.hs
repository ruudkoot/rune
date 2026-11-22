-- Report 4.4.3.1: g 0 y = y is a function of two arguments: seq (g bottom) 1 is 1; f 0 = \y -> y is one of
-- one: seq (f bottom) 1 diverges.
module Main (main) where

f :: Int -> Int -> Int
f 0 = \y -> y

g :: Int -> Int -> Int
g 0 y = y

main :: IO ()
main = do
  print (seq (g undefined) (1 :: Int))
  print (seq (f undefined) (1 :: Int))
