-- Report 4.4.3.1: f 0 _ = 1; f _ 0 = 2: f bottom 0 diverges on its first argument.
module Main (main) where

f :: Int -> Int -> Int
f 0 _ = 1
f _ 0 = 2

main :: IO ()
main = print (f undefined 0)
