-- Report 4.3.1: a class has exactly one type variable: not class C a b.
module Main (main) where

class C a b where

main :: IO ()
main = return ()
