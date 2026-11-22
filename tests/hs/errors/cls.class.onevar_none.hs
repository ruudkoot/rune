-- Report 4.3.1: a class has exactly one type variable: not class C.
module Main (main) where

class C where

main :: IO ()
main = return ()
