-- Report 3.17.1: an integer literal pattern needs Num: f :: Char -> Int; f 0 = 1.
module Main (main) where

f :: Char -> Int
f 0 = 1

main :: IO ()
main = return ()
