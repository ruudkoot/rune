-- Report 3.17.1: _ is a pattern, no expression: not f = _.
module Main (main) where

f :: Int
f = _

main :: IO ()
main = return ()
