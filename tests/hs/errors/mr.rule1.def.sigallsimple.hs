-- Report 4.5.5, Rule 1: every simply bound variable of the group needs a signature: y has none.
module Main (main) where

x :: Num a => a
x = y
y = x + 1

main :: IO ()
main = print (y :: Int, y :: Double)
