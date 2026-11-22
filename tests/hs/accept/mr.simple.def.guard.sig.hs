-- rows: R18
-- Report 4.5.5: a simple pattern binding is one variable, guards allowed, so x | True = 1 signed is unrestricted (R18: rhc
-- takes 4.5.5's definition, D32).
module Main (main) where

x :: Num a => a
x | True = 1

main :: IO ()
main = print (x :: Int, x :: Double)
