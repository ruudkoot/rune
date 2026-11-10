-- Report 10: Enum derives for an enumeration only: no fields.
module Main (main) where

data T = A Int deriving Enum

main :: IO ()
main = return ()
