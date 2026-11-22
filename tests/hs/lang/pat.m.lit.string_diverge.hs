-- rows: pat.m.lit.diverge
-- Report 3.17.2: a string literal pattern against 'a':undefined diverges: the test diverges.
module Main (main) where

s :: String -> Int
s "ab" = 1
s _ = 2

main :: IO ()
main = print (s ('a' : undefined))
