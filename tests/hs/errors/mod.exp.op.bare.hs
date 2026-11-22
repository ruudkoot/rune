-- Report 5.2: export -> qvar | ..., and qvar is a parenthesised symbol: a bare operator is no export.
module Main (main, +++) where

(+++) :: Int -> Int -> Int
a +++ b = a

main :: IO ()
main = return ()
