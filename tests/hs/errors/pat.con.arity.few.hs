-- Report 3.17.1: a constructor in a pattern has all its arguments.
module Main (main) where

f :: Maybe Int -> Int
f Just = 1

main :: IO ()
main = return ()
