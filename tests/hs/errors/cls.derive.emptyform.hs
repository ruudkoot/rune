-- Report 4.3.3: deriving () derives nothing.
module Main (main) where

data T = A deriving ()

x :: Bool
x = A == A

main :: IO ()
main = return ()
