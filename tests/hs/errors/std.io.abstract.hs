-- Report 6.1.7: IO is abstract: no constructor of it is visible.
module Main (main) where

x :: IO ()
x = IO undefined

main :: IO ()
main = return ()
