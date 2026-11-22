-- Report 7.3, 8: IOError is abstract: its constructors are not visible.
module Main (main) where

f :: IOError -> Int
f (IOError x) = 1

main :: IO ()
main = return ()
