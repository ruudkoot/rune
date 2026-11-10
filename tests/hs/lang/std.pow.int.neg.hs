-- Report 6.4.3: x ^ n with a negative exponent is an error: 2 ^ (-1).
module Main (main) where

main :: IO ()
main = print (2 ^ (-1 :: Int) :: Int)
