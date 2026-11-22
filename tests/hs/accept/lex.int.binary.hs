-- Report 2.5: integer -> decimal | 0o octal | 0O octal | 0x hexadecimal | 0X hexadecimal, and nothing else: there is
-- no binary literal, so `0b1` is `0` then the varid `b1`, two patterns of f.
module Main (main) where

f :: Int -> Int -> Int
f 0b1 = b1
f _ _ = 0

main :: IO ()
main = print (f 0 1)
