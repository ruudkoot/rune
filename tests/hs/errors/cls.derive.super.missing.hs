-- Report 4.3.3: the superclasses' instances exist: deriving Ord without Eq.
module Main (main) where

data T = A deriving Ord

main :: IO ()
main = return ()
