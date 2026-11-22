-- Report 10: with no deriving clause there is no instance.
module Main (main) where

data T = A

x :: Bool
x = A == A

main :: IO ()
main = return ()
