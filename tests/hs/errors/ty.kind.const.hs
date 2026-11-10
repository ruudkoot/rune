-- Report 4.1.2: Char, Int, Integer, Float, Double and Bool have kind *: not Char Int.
module Main (main) where

x :: Char Int
x = undefined

main :: IO ()
main = return ()
