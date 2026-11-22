-- Report 10.1: A == undefined is bottom, a single nullary constructor too.
module Main (main) where

data T = A deriving Eq

main :: IO ()
main = print (A == (undefined :: T))
