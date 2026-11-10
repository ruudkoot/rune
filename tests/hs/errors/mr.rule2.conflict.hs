-- Report 4.5.5, Rule 2: two uses at two types conflict.
module Main (main) where

x = 1

a :: Int
a = x

b :: Double
b = x

main :: IO ()
main = return ()
