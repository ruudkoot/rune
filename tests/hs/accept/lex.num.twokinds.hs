-- Report 2.5: "There are two distinct kinds of numeric literals: integer and floating": an integer literal at a type
-- in Num and not Fractional, a floating one at one in Fractional.
module Main (main) where

main :: IO ()
main = print (1 :: Int, 1.0 :: Double, 1 :: Double)
