-- Report 3.1: undefined terminates the program as error does.
module Main (main) where

main :: IO ()
main = print (undefined :: Int)
