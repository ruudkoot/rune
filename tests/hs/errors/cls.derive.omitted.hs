-- Report 4.3.3: with no deriving form nothing is derived.
module Main (main) where

data T = A

x :: Bool
x = A == A

main :: IO ()
main = return ()
