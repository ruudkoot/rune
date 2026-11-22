-- Report 3: a let is an exp10, so no unparenthesised argument: f let {} in 1.
module Main (main) where

x :: Int
x = negate let {} in 1

main :: IO ()
main = return ()
