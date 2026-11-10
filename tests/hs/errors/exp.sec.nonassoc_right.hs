-- Report 3.5: a section of a non-associative operator holds no chain of it: not (== a == b).
module Main (main) where

main :: IO ()
main = print ((== True == True) True)
