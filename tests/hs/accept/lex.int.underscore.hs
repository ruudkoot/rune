-- rows: R58
-- Report 2.5: decimal -> digit{digit}, with no separator: `1_000` is `1` then the varid `_000`, two patterns of f.
module Main (main) where

f :: Int -> Int -> Int
f 1_000 = _000
f _ _ = 0

main :: IO ()
main = print (f 1 2)
