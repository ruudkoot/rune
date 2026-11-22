-- Report 3.7: a list of t has type [t].
module Main (main) where

xs :: [Int]
xs = [1, 2] :: [Int]

main :: IO ()
main = return ()
