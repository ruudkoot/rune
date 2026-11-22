-- Report 3.15.1: a selector is a top-level name: defining it again is refused.
module Main (main) where

data T = T {f :: Int}

f :: Int
f = 1

main :: IO ()
main = return ()
