-- Report 3.17.1: _ may occur more than once.
module Main (main) where

f :: Int -> Int -> Int
f _ _ = 1

main :: IO ()
main = return ()
