-- Report 3.17.1: lpat6 -> - (integer | float): only a literal follows the - of a pattern: not f (-x).
module Main (main) where

f :: Int -> Int
f (-x) = x

main :: IO ()
main = return ()
