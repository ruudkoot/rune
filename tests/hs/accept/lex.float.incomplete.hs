-- Report 2.5, maximal munch: an exponent needs its digits, so `1e` is `1` then the varid `e`: two patterns of f.
module Main (main) where

f :: Int -> Int -> Int
f 1e = e
f _ _ = 0

main :: IO ()
main = print (f 1 2)
