-- Report 10.1: max is strict.
module Main (main) where

data T = A | B deriving (Eq, Ord, Show)

main :: IO ()
main = print (max A (undefined :: T))
