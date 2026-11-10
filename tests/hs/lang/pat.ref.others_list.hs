-- rows: pat.ref.def
-- Report 3.17.2: a list pattern is refutable: on bottom it diverges.
module Main (main) where

main :: IO ()
main = print ((\[x] -> x) (undefined :: [Int]))
