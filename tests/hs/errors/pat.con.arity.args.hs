-- Report 3.17.1: a constructor of arity k >= 1 is no apat alone: not f Just x = 1.
module Main (main) where

f :: (Int -> Maybe Int) -> Int -> Int
f Just x = 1

main :: IO ()
main = return ()
