-- Report 4.2.1: a label in two constructors has one type.
module Main (main) where

data T = T1 { y :: Int } | T2 { y :: Bool }

main :: IO ()
main = return ()
