-- Report 6.4.1: a floating literal is no integral value.
module Main (main) where

x :: Int
x = 1.5

main :: IO ()
main = return ()
