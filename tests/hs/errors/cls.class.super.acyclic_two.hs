-- Report 4.3.1: the superclass relation is not cyclic: C and D.
module Main (main) where

class D a => C a
class C a => D a

main :: IO ()
main = return ()
