-- Report 10.1: A /= undefined is bottom.
module Main (main) where

data T = A | B deriving Eq

main :: IO ()
main = print (A /= (undefined :: T))
