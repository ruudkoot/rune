-- Report 3.11: a generator's variables scope only to its right.
module Main (main) where

xs :: [Int]
xs = [x | y > 0, y <- [1, 2], x <- [y]]

main :: IO ()
main = return ()
