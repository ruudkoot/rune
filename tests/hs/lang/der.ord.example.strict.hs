-- Report 10.1: (undefined, 1) < (undefined, 2) is bottom.
module Main (main) where

main :: IO ()
main = print ((undefined :: Int, 1 :: Int) < (undefined, 2))
