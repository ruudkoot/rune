-- Report 10.1: compare is strict in both arguments.
module Main (main) where

data T = A | B deriving (Eq, Ord)

main :: IO ()
main = print (compare A (undefined :: T))
