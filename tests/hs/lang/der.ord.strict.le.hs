-- Report 10.1: <= is strict.
module Main (main) where

data T = A | B deriving (Eq, Ord)

main :: IO ()
main = print (A <= (undefined :: T))
