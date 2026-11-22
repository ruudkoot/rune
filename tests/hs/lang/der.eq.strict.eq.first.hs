-- Report 10.1: undefined == A is bottom.
module Main (main) where

data T = A deriving Eq

main :: IO ()
main = print ((undefined :: T) == A)
