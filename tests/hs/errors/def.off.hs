-- Report 4.3.4: default () turns defaulting off: show 1 is ambiguous.
module Main (main) where

default ()

main :: IO ()
main = putStrLn (show 1)
