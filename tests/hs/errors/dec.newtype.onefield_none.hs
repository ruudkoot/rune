-- Report 4.2.3: the constructor of a newtype has exactly one field: not A alone.
module Main (main) where

newtype T = A

main :: IO ()
main = return ()
