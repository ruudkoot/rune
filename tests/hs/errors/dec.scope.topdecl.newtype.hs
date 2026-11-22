-- Report 4: a newtype declaration stands only at the top level: not in a let.
module Main (main) where

x :: Int
x = let newtype N = N Int in 1

main :: IO ()
main = return ()
