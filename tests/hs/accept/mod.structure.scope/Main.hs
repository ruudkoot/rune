-- Report 5.1: a module is one mutually recursive scope: uses before definitions, both ways.
module Main (main) where

main :: IO ()
main = print (a, b)

a :: Int
a = b + 1

b :: Int
b = 2
