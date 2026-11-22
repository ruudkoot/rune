-- Report 2.4: varid excludes reservedid, so a reserved word after a qualifier is no qualified name: maximal munch reads
-- `Just.let` as `Just`, `.`, `let`, as it reads `M.where` (D38: rhc follows 2.4 here, against the oracles).
module Main (main) where

f :: Int -> Maybe Int
f = Just.let g = id in g

main :: IO ()
main = print (f 1)
