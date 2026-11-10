-- Report 6.2: seq bottom b is bottom.
module Main (main) where

main :: IO ()
main = print (seq (undefined :: Int) (1 :: Int))
