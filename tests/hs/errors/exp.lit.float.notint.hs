-- Report 3.2: a floating literal is Fractional: 1.5 :: Int is refused.
module Main (main) where

x :: Int
x = 1.5

main :: IO ()
main = return ()
