-- Report 3.9: () is the only member of its type but bottom: case undefined of () -> 1 diverges, () being a constructor.
module Main (main) where

main :: IO ()
main = print (case undefined of () -> 1 :: Int)
