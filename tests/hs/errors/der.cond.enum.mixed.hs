-- Report 10: Enum derives for an enumeration only.
module Main (main) where

data T = A | B Int deriving Enum

main :: IO ()
main = return ()
