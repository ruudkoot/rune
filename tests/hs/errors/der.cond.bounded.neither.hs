-- Report 10: Bounded derives for an enumeration or a single constructor only.
module Main (main) where

data T = A Int | B deriving Bounded

main :: IO ()
main = return ()
