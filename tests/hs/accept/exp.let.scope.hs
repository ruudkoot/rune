-- Report 3.12: a let's declarations scope over each other: the order is irrelevant.
module Main (main) where

x :: Int
x = let a = b + 1
        b = 2
    in a

main :: IO ()
main = return ()
