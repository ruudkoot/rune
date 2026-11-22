-- Report 2.5, maximal munch: `0x` not followed by a hexit lexes as `0` then a varid, so `0xg` is two patterns of f.
module Main (main) where

f :: Int -> Int -> Int
f 0xg = xg
f _ _ = 0

main :: IO ()
main = print (f 0 1)
