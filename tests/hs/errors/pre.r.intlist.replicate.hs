-- Report 8: replicate takes an Int.
module Main (main) where

x :: [Char]
x = replicate (2 :: Integer) 'a'
main :: IO ()
main = return ()
