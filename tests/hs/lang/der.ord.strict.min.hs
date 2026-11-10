-- Report 10.1: min is strict.
module Main (main) where

data T = A | B deriving (Eq, Ord, Show)

main :: IO ()
main = print (min (undefined :: T) B)
