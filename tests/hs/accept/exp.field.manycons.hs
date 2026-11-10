-- Report 3.15.1: a field may be in several constructors at one type.
module Main (main) where

data S = S1 { x :: Int } | S2 { x :: Int }

main :: IO ()
main = return ()
