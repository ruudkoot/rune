-- Report 4.4.1: nor for a lambda's variable in a let.
module Main (main) where

h :: Int -> Int
h = \x -> let x :: Int in x

main :: IO ()
main = return ()
