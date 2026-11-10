-- Report 4.3.1: the superclass relation is not cyclic: C of itself.
module Main (main) where

class C a => C a

main :: IO ()
main = return ()
