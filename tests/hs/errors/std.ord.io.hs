-- Report 6.3.2: IO is not in Ord.
module Main (main) where

x :: Bool
x = getChar < getChar

main :: IO ()
main = return ()
