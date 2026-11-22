-- Report 4.5.5, Rule 1: a guarded single variable is restricted without a signature.
module Main (main) where

x | True = 1

main :: IO ()
main = print (x :: Int, x :: Double)
