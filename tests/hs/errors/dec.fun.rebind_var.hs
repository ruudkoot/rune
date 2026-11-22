-- Report 4.4.3.1: a variable has one binding in a declaration list: x twice.
module Main (main) where

x :: Int
x = 1
y :: Int
y = 2
x = 3

main :: IO ()
main = return ()
