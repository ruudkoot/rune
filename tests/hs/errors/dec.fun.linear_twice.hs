-- Report 4.4.3.1: no variable twice among a clause's patterns: f x x.
module Main (main) where

f :: Int -> Int -> Int
f x x = 1

main :: IO ()
main = return ()
