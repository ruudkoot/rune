-- Report 4.2.3: the constructor of a newtype has exactly one field: not A Int Int.
module Main (main) where

newtype T = A Int Int

main :: IO ()
main = return ()
