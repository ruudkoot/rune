-- Report 6.1.7: IOError is abstract.
module Main (main) where

x :: IOError
x = IOError

main :: IO ()
main = return ()
