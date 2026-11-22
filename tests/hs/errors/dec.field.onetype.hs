-- Report 4.2.1: a label is not shared by two types in scope.
module Main (main) where

data A = A { x :: Int }
data B = B { x :: Int }

main :: IO ()
main = return ()
