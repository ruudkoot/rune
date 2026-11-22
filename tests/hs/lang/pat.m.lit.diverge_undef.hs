-- rows: pat.ref.def
-- Report 3.17.2: a literal pattern against bottom diverges: case undefined of 0 -> 1.
module Main (main) where

main :: IO ()
main = print (case undefined :: Int of { 0 -> 1; _ -> 2 :: Int })
