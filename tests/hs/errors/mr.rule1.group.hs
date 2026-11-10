-- Report 4.5.5, Rule 1: a function binding in a restricted group is restricted: f with y.
module Main (main) where

f x = y + x
y = f 1

main :: IO ()
main = print (f (1 :: Int), f (1 :: Double))
