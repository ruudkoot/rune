-- Report 3.3: \ p1 ... pn -> e, n >= 1: a lambda has a pattern.
module Main (main) where

x :: Int
x = (\ -> 1)

main :: IO ()
main = return ()
