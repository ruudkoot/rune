-- Report 4.3.4: not Char either.
module Main (main) where

default (Int, Char)

main :: IO ()
main = return ()
