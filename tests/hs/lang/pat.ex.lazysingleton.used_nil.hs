-- rows: pat.m.irref.bottom
-- Report 3.17.2: (\ ~[x] -> x) [] is bottom: x is demanded and its match fails.
module Main (main) where

main :: IO ()
main = print ((\ ~[x] -> x) ([] :: [Int]))
