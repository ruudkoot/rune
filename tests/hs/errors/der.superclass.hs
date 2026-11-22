-- Report 4.3.3, 10: deriving a class needs instances of its superclasses: Ord without Eq.
module Main (main) where

data T = A | B deriving Ord

main :: IO ()
main = return ()
