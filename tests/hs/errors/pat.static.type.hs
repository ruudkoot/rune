-- Report 3.17: a pattern has the matched value's type.
module Main (main) where

f :: Int
f = case True of 'a' -> 1

main :: IO ()
main = return ()
