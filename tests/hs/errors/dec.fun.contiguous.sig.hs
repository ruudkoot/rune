-- Report 4.4.3.1: a signature between clauses breaks them.
module Main (main) where

f 0 = 1
f :: Int -> Int
f n = n

main :: IO ()
main = return ()
