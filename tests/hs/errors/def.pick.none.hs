-- Report 4.3.4: no type of the default list fits: default (Int) and a Fractional literal.
module Main (main) where

default (Int)

main :: IO ()
main = print 1.5
