-- Report 3.17.1: a floating literal pattern needs Fractional.
module Main (main) where

f :: Int -> Int
f 1.5 = 1

main :: IO ()
main = return ()
