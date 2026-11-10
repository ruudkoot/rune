-- Report 5: the value main's action returns is discarded: main = return undefined ends in success.
module Main (main) where

main :: IO ()
main = return undefined
