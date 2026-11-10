-- Report 7.1: print takes a Show: print id is refused.
module Main (main) where

main :: IO ()
main = print id
