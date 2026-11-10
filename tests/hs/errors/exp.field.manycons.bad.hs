-- Report 3.15.1: a field in several constructors has one type.
module Main (main) where

data T = T1 { y :: Int } | T2 { y :: Bool }

main :: IO ()
main = return ()
