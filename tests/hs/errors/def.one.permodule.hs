-- Report 4.3.4: one default declaration per module.
module Main (main) where

default (Integer)
default (Double)

main :: IO ()
main = return ()
