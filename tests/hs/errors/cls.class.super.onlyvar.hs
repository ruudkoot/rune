-- Report 4.3.1: the only type variable of a class's context is its own.
module Main (main) where

class Eq b => C a

main :: IO ()
main = return ()
