-- Report 6.3.1: IO is not in Eq.
module Main (main) where

x :: Bool
x = getChar == getChar

main :: IO ()
main = return ()
