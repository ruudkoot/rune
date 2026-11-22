-- rows: pat.ref.def
-- Report 3.17.2: n+k against bottom diverges: the comparison does.
module Main (main) where

main :: IO ()
main = print (case undefined :: Int of { n + 1 -> n; _ -> 0 })
